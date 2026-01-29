package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	apperrors "github.com/irvingmg/skilloper/skilloper-api/internal/errors"
	"github.com/irvingmg/skilloper/skilloper-api/internal/middleware"
	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
	"github.com/irvingmg/skilloper/skilloper-api/internal/services"
)

type CollectionHandler struct {
	service *services.CollectionService
	log     *zap.Logger
	errH    *ErrorHandler
}

func NewCollectionHandler(service *services.CollectionService, errH *ErrorHandler, log *zap.Logger) *CollectionHandler {
	return &CollectionHandler{
		service: service,
		log:     log,
		errH:    errH,
	}
}

// GetCollections handles GET /collections
func (h *CollectionHandler) GetCollections(c *gin.Context) {
	h.log.Debug("Fetching collections")

	userID := middleware.GetUserID(c)
	isAdmin := middleware.IsAdmin(c)

	var params models.CollectionPaginationParams
	if err := c.ShouldBindQuery(&params); err != nil {
		h.errH.Handle(c, apperrors.ErrInvalidPaginationParams, "parse_pagination_params")
		return
	}
	params.Validate()

	h.log.Debug("Collection pagination params",
		zap.Int("limit", params.Limit),
		zap.Int("offset", params.Offset),
		zap.String("search", params.Search),
		zap.String("sort", params.Sort),
		zap.Uintp("parent_id", params.ParentID))

	result, err := h.service.GetPaginatedSummaries(params, userID, isAdmin)
	if err != nil {
		h.errH.Handle(c, err, "fetch_collections")
		return
	}

	h.log.Debug("Successfully fetched collections",
		zap.Int("count", len(result.Data)),
		zap.Int("total", result.Pagination.TotalCount))
	c.JSON(http.StatusOK, result)
}

// GetCollection handles GET /collections/:id
func (h *CollectionHandler) GetCollection(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		h.errH.Handle(c, apperrors.ErrInvalidCollectionID, "parse_collection_id")
		return
	}

	userID := middleware.GetUserID(c)
	isAdmin := middleware.IsAdmin(c)

	h.log.Debug("Fetching collection", zap.Int("id", id))

	collection, err := h.service.GetByID(uint(id), userID, isAdmin)
	if err != nil {
		h.errH.Handle(c, err, "fetch_collection")
		return
	}

	h.log.Debug("Successfully fetched collection",
		zap.Int("id", id),
		zap.String("name", collection.Name))
	c.JSON(http.StatusOK, collection)
}

// CreateCollection handles POST /collections
func (h *CollectionHandler) CreateCollection(c *gin.Context) {
	userID := middleware.GetUserID(c)

	h.log.Debug("Creating new collection")

	var req models.CreateCollectionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.errH.Handle(c, apperrors.ErrInvalidJSONFormat, "parse_create_request")
		return
	}

	h.log.Debug("Creating collection", zap.String("name", req.Name))

	collection, err := h.service.Create(req, userID)
	if err != nil {
		h.errH.Handle(c, err, "create_collection")
		return
	}

	h.log.Debug("Successfully created collection",
		zap.Uint("id", collection.ID),
		zap.String("name", collection.Name))
	c.JSON(http.StatusCreated, collection)
}

// UpdateCollection handles PUT /collections/:id
func (h *CollectionHandler) UpdateCollection(c *gin.Context) {
	userID := middleware.GetUserID(c)
	isAdmin := middleware.IsAdmin(c)
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		h.errH.Handle(c, apperrors.ErrInvalidCollectionID, "parse_collection_id")
		return
	}

	h.log.Debug("Updating collection", zap.Int("id", id))

	var req models.CreateCollectionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.errH.Handle(c, apperrors.ErrInvalidJSONFormat, "parse_update_request")
		return
	}

	collection, err := h.service.Update(uint(id), req, userID, isAdmin)
	if err != nil {
		h.errH.Handle(c, err, "update_collection")
		return
	}

	h.log.Debug("Successfully updated collection",
		zap.Int("id", id),
		zap.String("name", collection.Name))
	c.JSON(http.StatusOK, collection)
}

// DeleteCollection handles DELETE /collections/:id
func (h *CollectionHandler) DeleteCollection(c *gin.Context) {
	userID := middleware.GetUserID(c)
	isAdmin := middleware.IsAdmin(c)
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		h.errH.Handle(c, apperrors.ErrInvalidCollectionID, "parse_collection_id")
		return
	}

	h.log.Debug("Deleting collection", zap.Int("id", id))

	err = h.service.Delete(uint(id), userID, isAdmin)
	if err != nil {
		h.errH.Handle(c, err, "delete_collection")
		return
	}

	h.log.Debug("Successfully deleted collection", zap.Int("id", id))
	c.Status(http.StatusNoContent)
}

// GetCollectionsFlat handles GET /collections/flat
func (h *CollectionHandler) GetCollectionsFlat(c *gin.Context) {
	userID := middleware.GetUserID(c)
	isAdmin := middleware.IsAdmin(c)

	h.log.Debug("Fetching flat collections list")

	collections, err := h.service.GetAllFlat(userID, isAdmin)
	if err != nil {
		h.errH.Handle(c, err, "fetch_collections_flat")
		return
	}

	h.log.Debug("Successfully fetched flat collections", zap.Int("count", len(collections)))
	c.JSON(http.StatusOK, collections)
}
