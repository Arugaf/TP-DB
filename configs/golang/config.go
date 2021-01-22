package config

type DBConf struct {
	User     string
	Password string
	DBName   string
	Port     string
}

var PostgresConf DBConf

func init() {
	PostgresConf = DBConf{
		User:     "docker",
		Password: "qwerty123456",
		DBName:   "forum-tp",
		Port:     "5432",
	}
}
