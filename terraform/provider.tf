provider "google" {
  credentials = file("account.json")      
  project     = "project-179cc51b-9587-46f6-aac" 
  region      = "asia-northeast3"         
  zone        = "asia-northeast3-a"
}