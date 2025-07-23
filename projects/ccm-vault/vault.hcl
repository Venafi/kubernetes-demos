plugin_directory = "./vault_plugins"

listener "tcp" {
  address     = "127.0.0.1:8200"
  tls_disable = true
}

storage "file" {
  path = "./vault_data"
}

disable_mlock = true

ui = true