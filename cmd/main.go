package main

import (
	"TP-DB/configs/golang"

	_forumHandlers "TP-DB/pkg/forum/delivery"
	_forumRepo "TP-DB/pkg/forum/repository"
	_userHandlers "TP-DB/pkg/user/delivery"
	_userRepo "TP-DB/pkg/user/repository"

	"fmt"

	"github.com/fasthttp/router"
	"github.com/jackc/pgx"
	"github.com/rs/zerolog/log"
	"github.com/valyala/fasthttp"
)

func applicationJSON(next fasthttp.RequestHandler) fasthttp.RequestHandler {
	return func(ctx *fasthttp.RequestCtx) {
		ctx.Response.Header.Set("Content-Type", "application/json")
		next(ctx)
	}
}

func main() {
	r := router.New()

	connStr := fmt.Sprintf("user=%s password=%s dbname=%s sslmode=disable port=%s",
		config.PostgresConf.User,
		config.PostgresConf.Password,
		config.PostgresConf.DBName,
		config.PostgresConf.Port)

	pgxConn, err := pgx.ParseConnectionString(connStr)
	if err != nil {
		log.Error().Msgf(err.Error())
		return
	}

	pgxConn.PreferSimpleProtocol = true

	cfg := pgx.ConnPoolConfig{
		ConnConfig:     pgxConn,
		MaxConnections: 100,
		AfterConnect:   nil,
		AcquireTimeout: 0,
	}

	connPool, err := pgx.NewConnPool(cfg)
	if err != nil {
		log.Error().Msgf(err.Error())
	}

	userRepo := _userRepo.NewPostgresCafeRepository(connPool)
	forumRepo := _forumRepo.NewPostgresForumRepository(connPool, userRepo)

	_userHandlers.NewUserHandler(r, userRepo, forumRepo)
	_forumHandlers.NewForumHandler(r, forumRepo, userRepo)

	log.Error().Msgf(fasthttp.ListenAndServe(":5000", applicationJSON(r.Handler)).Error())
}
