variable "project_id" {
  description = "GCP project dedicated to ephemeral GitHub GPU runners."
  type        = string
}

variable "github_repository" {
  description = "Exact owner/repository allowed to exchange GitHub OIDC tokens."
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be owner/repository."
  }
}

variable "pool_id" {
  description = "Workload Identity Pool ID."
  type        = string
  default     = "github-actions"
}

variable "provider_id" {
  description = "Workload Identity Provider ID."
  type        = string
  default     = "github"
}
