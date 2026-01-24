package middleware

import (
	"context"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gin-gonic/gin/binding"
	"github.com/redis/go-redis/v9"
	"github.com/ulule/limiter/v3"
	mgin "github.com/ulule/limiter/v3/drivers/middleware/gin"
	sredis "github.com/ulule/limiter/v3/drivers/store/redis"
	"go.uber.org/zap"

	"github.com/irvingmg/skilloper/skilloper-api/internal/config"
	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
)

const (
	redisConnectTimeout = 5 * time.Second
	ipRateMultiplier    = 3 // IP-only limits are 3x the per-user limits
)

type RateLimiters struct {
	Login       gin.HandlerFunc
	Register    gin.HandlerFunc
	API         gin.HandlerFunc
	redisClient *redis.Client
}

func (r *RateLimiters) Close() {
	if r.redisClient != nil {
		_ = r.redisClient.Close()
	}
}

func NewRateLimiters(cfg config.RateLimitConfig, redisCfg config.RedisConfig, log *zap.Logger) (*RateLimiters, error) {
	noop := func(c *gin.Context) { c.Next() }

	if !cfg.Enabled {
		log.Info("Rate limiting disabled")
		return &RateLimiters{Login: noop, Register: noop, API: noop}, nil
	}

	if redisCfg.URL == "" {
		if cfg.GracefulFallback {
			log.Warn("REDIS_URL not set, rate limiting disabled (graceful fallback)")
			return &RateLimiters{Login: noop, Register: noop, API: noop}, nil
		}
		log.Error("REDIS_URL is required when RATE_LIMIT_ENABLED=true")
		return nil, fmt.Errorf("REDIS_URL is required when RATE_LIMIT_ENABLED=true")
	}

	opt, err := redis.ParseURL(redisCfg.URL)
	if err != nil {
		if cfg.GracefulFallback {
			log.Warn("Failed to parse Redis URL, rate limiting disabled (graceful fallback)", zap.Error(err))
			return &RateLimiters{Login: noop, Register: noop, API: noop}, nil
		}
		log.Error("Failed to parse Redis URL", zap.Error(err))
		return nil, err
	}

	client := redis.NewClient(opt)
	ctx, cancel := context.WithTimeout(context.Background(), redisConnectTimeout)
	defer cancel()
	if err := client.Ping(ctx).Err(); err != nil {
		if closeErr := client.Close(); closeErr != nil {
			log.Warn("Failed to close Redis client", zap.Error(closeErr))
		}
		if cfg.GracefulFallback {
			log.Warn("Failed to connect to Redis, rate limiting disabled (graceful fallback)",
				zap.Error(err), zap.Duration("timeout", redisConnectTimeout))
			return &RateLimiters{Login: noop, Register: noop, API: noop}, nil
		}
		log.Error("Failed to connect to Redis", zap.Error(err), zap.Duration("timeout", redisConnectTimeout))
		return nil, err
	}

	store, err := sredis.NewStoreWithOptions(client, limiter.StoreOptions{
		Prefix: redisCfg.KeyPrefix,
	})
	if err != nil {
		if closeErr := client.Close(); closeErr != nil {
			log.Warn("Failed to close Redis client", zap.Error(closeErr))
		}
		log.Error("Failed to create Redis store", zap.Error(err))
		return nil, err
	}

	loginRate, err := limiter.NewRateFromFormatted(cfg.LoginRate)
	if err != nil {
		if closeErr := client.Close(); closeErr != nil {
			log.Warn("Failed to close Redis client", zap.Error(closeErr))
		}
		log.Error("Invalid login rate format", zap.String("rate", cfg.LoginRate), zap.Error(err))
		return nil, err
	}

	registerRate, err := limiter.NewRateFromFormatted(cfg.RegisterRate)
	if err != nil {
		if closeErr := client.Close(); closeErr != nil {
			log.Warn("Failed to close Redis client", zap.Error(closeErr))
		}
		log.Error("Invalid register rate format", zap.String("rate", cfg.RegisterRate), zap.Error(err))
		return nil, err
	}

	apiRate, err := limiter.NewRateFromFormatted(cfg.APIRate)
	if err != nil {
		if closeErr := client.Close(); closeErr != nil {
			log.Warn("Failed to close Redis client", zap.Error(closeErr))
		}
		log.Error("Invalid API rate format", zap.String("rate", cfg.APIRate), zap.Error(err))
		return nil, err
	}

	limitReachedHandler := func(c *gin.Context) {
		resetTime := c.Writer.Header().Get("X-RateLimit-Reset")
		if resetTime != "" {
			if resetUnix, err := strconv.ParseInt(resetTime, 10, 64); err == nil {
				retryAfter := resetUnix - time.Now().Unix()
				if retryAfter < 1 {
					retryAfter = 1
				}
				c.Header("Retry-After", strconv.FormatInt(retryAfter, 10))
			}
		}
		c.JSON(http.StatusTooManyRequests, gin.H{
			"error": "Too many requests. Please try again later.",
			"code":  "RATE_LIMIT_EXCEEDED",
		})
	}

	loginLimiter := limiter.New(store, loginRate)
	registerLimiter := limiter.New(store, registerRate)
	apiLimiter := limiter.New(store, apiRate)

	// IP-only limiters (multiplied from per-user limits) to prevent username rotation attacks
	loginIPRate := limiter.Rate{
		Limit:  loginRate.Limit * ipRateMultiplier,
		Period: loginRate.Period,
	}
	registerIPRate := limiter.Rate{
		Limit:  registerRate.Limit * ipRateMultiplier,
		Period: registerRate.Period,
	}
	loginIPLimiter := limiter.New(store, loginIPRate)
	registerIPLimiter := limiter.New(store, registerIPRate)

	loginIPKeyGetter := func(c *gin.Context) string {
		return fmt.Sprintf("login:ip:%s", c.ClientIP())
	}

	loginUserKeyGetter := func(c *gin.Context) string {
		var req struct {
			Username string `json:"username"`
		}
		if err := c.ShouldBindBodyWith(&req, binding.JSON); err == nil && req.Username != "" {
			return fmt.Sprintf("login:user:%s:%s", c.ClientIP(), models.NormalizeUsername(req.Username))
		}
		return fmt.Sprintf("login:ip:%s", c.ClientIP())
	}

	registerIPKeyGetter := func(c *gin.Context) string {
		return fmt.Sprintf("register:ip:%s", c.ClientIP())
	}

	registerUserKeyGetter := func(c *gin.Context) string {
		var req struct {
			Username string `json:"username"`
		}
		if err := c.ShouldBindBodyWith(&req, binding.JSON); err == nil && req.Username != "" {
			return fmt.Sprintf("register:user:%s:%s", c.ClientIP(), models.NormalizeUsername(req.Username))
		}
		return fmt.Sprintf("register:ip:%s", c.ClientIP())
	}

	apiKeyGetter := func(c *gin.Context) string {
		if userID, exists := c.Get(UserIDKey); exists {
			if id, ok := userID.(uint); ok && id > 0 {
				return fmt.Sprintf("api:user:%d", id)
			}
		}
		return fmt.Sprintf("api:%s", c.ClientIP())
	}

	checkLimit := func(c *gin.Context, lim *limiter.Limiter, keyGetter func(*gin.Context) string) bool {
		key := keyGetter(c)
		ctx, err := lim.Get(c, key)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Rate limit check failed",
				"code":  "RATE_LIMIT_ERROR",
			})
			c.Abort()
			return false
		}

		c.Header("X-RateLimit-Limit", strconv.FormatInt(ctx.Limit, 10))
		c.Header("X-RateLimit-Remaining", strconv.FormatInt(ctx.Remaining, 10))
		c.Header("X-RateLimit-Reset", strconv.FormatInt(ctx.Reset, 10))

		if ctx.Reached {
			limitReachedHandler(c)
			c.Abort()
			return false
		}
		return true
	}

	loginComposite := func(c *gin.Context) {
		if !checkLimit(c, loginIPLimiter, loginIPKeyGetter) {
			return
		}
		if !checkLimit(c, loginLimiter, loginUserKeyGetter) {
			return
		}
		c.Next()
	}

	registerComposite := func(c *gin.Context) {
		if !checkLimit(c, registerIPLimiter, registerIPKeyGetter) {
			return
		}
		if !checkLimit(c, registerLimiter, registerUserKeyGetter) {
			return
		}
		c.Next()
	}

	log.Info("Rate limiters initialized",
		zap.String("login_rate", cfg.LoginRate),
		zap.String("register_rate", cfg.RegisterRate),
		zap.String("api_rate", cfg.APIRate),
		zap.Int64("ip_multiplier", ipRateMultiplier),
		zap.String("redis_prefix", redisCfg.KeyPrefix),
	)

	return &RateLimiters{
		Login:       loginComposite,
		Register:    registerComposite,
		API:         mgin.NewMiddleware(apiLimiter, mgin.WithLimitReachedHandler(limitReachedHandler), mgin.WithKeyGetter(apiKeyGetter)),
		redisClient: client,
	}, nil
}
