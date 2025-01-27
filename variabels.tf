variable "common-tags" {
  type        = map(string)
  default = {
    environment   = "test"
    owner         = "devops-team"
    client        = "fast-track"
    created_by    = "terraform"
  }
}