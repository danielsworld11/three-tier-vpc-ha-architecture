module "network" {
  source = "./modules/network"

  project_name             = var.project_name
  vpc_cidr                 = var.vpc_cidr
  azs                      = var.azs
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
}

module "security" {
  source = "./modules/security"

  project_name = var.project_name
  vpc_id       = module.network.vpc_id
}

module "compute" {
  source = "./modules/compute"

  project_name            = var.project_name
  vpc_id                  = module.network.vpc_id
  public_subnet_ids       = module.network.public_subnet_ids
  private_app_subnet_ids  = module.network.private_app_subnet_ids
  alb_sg_id               = module.security.alb_sg_id
  app_sg_id               = module.security.app_sg_id
  instance_type           = var.instance_type
  asg_min_size            = var.asg_min_size
  asg_max_size            = var.asg_max_size
  asg_desired_capacity    = var.asg_desired_capacity
}

module "database" {
  source = "./modules/database"

  project_name           = var.project_name
  private_db_subnet_ids  = module.network.private_db_subnet_ids
  db_sg_id               = module.security.db_sg_id
  db_engine              = var.db_engine
  db_engine_version      = var.db_engine_version
  db_instance_class      = var.db_instance_class
  db_allocated_storage   = var.db_allocated_storage
  db_name                = var.db_name
  db_username            = var.db_username
  db_password            = var.db_password
}
