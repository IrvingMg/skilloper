//go:build !noembed

package main

import "embed"

//go:embed static/*
var StaticFiles embed.FS
