package main

import "github.com/gin-gonic/gin"

func main() {
	g := gin.New()

	g.Use(gin.Logger())

	g.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status": "ok",
		})
	})

	if err := g.Run(":7070"); err != nil {
		panic(err)
	}
}
