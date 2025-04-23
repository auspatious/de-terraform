# PROD
init-prod:
	terraform -chdir=prod init

plan-prod:
	terraform -chdir=prod plan

upgrade-prod:
	terraform -chdir=prod init -upgrade

# STAGING
init-staging:
	terraform -chdir=staging init

plan-staging:
	terraform -chdir=staging plan

upgrade-staging:
	terraform -chdir=staging init -upgrade
