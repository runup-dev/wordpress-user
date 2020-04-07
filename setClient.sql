CREATE DATABASE IF NOT EXISTS wp_dowhastudio;
CREATE USER IF NOT EXISTS dowhastudio_www@localhost;
SET PASSWORD FOR dowhastudio_www@localhost= PASSWORD("dowhastudio@6951");
GRANT ALL PRIVILEGES ON wp_dowhastudio.* TO dowhastudio_www@localhost IDENTIFIED BY "dowhastudio@6951";
FLUSH PRIVILEGES;
