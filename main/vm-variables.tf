variable "platform_id" {
    type = string
    description = "standard-v1/standard-v2/standard-v3"
}
variable "vm-cores" {
    type = number
    description = "Core count"
}
variable "vm-ram" {
    type = number
    description = "RAM Volume"
}
variable "vm-core_fraction" {
    type = number
    description = "core fraction (in percent)"
}
variable "vm-preemptible" {
    type = bool
    description = "Preemptible (true/false)"
}
variable "vm-disk-image_id" {
    type = string
    description = "image id"
}
variable "vm-disk-size" {
    type = number
    description = "Disks volume"
}
variable "vm-disk-type" {
    type = string
}