read -n3 -p "Do you wish to destroy S3, RDS and AWS Secrets? [Yes|No]
" doit 
case $doit in  
  Yes|yes) destroy_all=true ;;
  *) destroy_all=false ;;
esac

# Need to add in here to uninstall Flux and also delete any ALBs and Spot instance requests spun up by Karpenter

if [ $destroy_all == true ]
    then
        # Empty the bucket
        terraform output -json | jq .public_bucket_name.value | xargs -i aws s3 rm s3://{} --recursive

        # Delete the bucket
        terraform output -json | jq .public_bucket_name.value | xargs -i aws s3 rb s3://{}

        # Remove the bucket from the state file
        terraform state rm module.resources.aws_s3_bucket.public

        # Delete the RDS database
        terraform output -json | jq .db_instance_identifier.value | xargs aws rds modify-db-instance --no-deletion-protection --region us-west-2 --db-instance-identifier
        terraform output -json | jq .db_instance_identifier.value | xargs aws rds delete-db-instance --skip-final-snapshot --region us-west-2 --db-instance-identifier

        # Remove the database from the state file
        terraform state rm module.resources.module.db.module.db_instance.aws_db_instance.this[0]

        # Remove secrets without recovery
        aws secretsmanager delete-secret --secret-id stacread-password --force-delete-without-recovery --region us-west-2
        aws secretsmanager delete-secret --secret-id db-password --force-delete-without-recovery --region us-west-2
        aws secretsmanager delete-secret --secret-id argo-password --force-delete-without-recovery --region us-west-2
        aws secretsmanager delete-secret --secret-id grafana-password --force-delete-without-recovery --region us-west-2
        aws secretsmanager delete-secret --secret-id jupyterhub-password --force-delete-without-recovery --region us-west-2
        aws secretsmanager delete-secret --secret-id stac-password --force-delete-without-recovery --region us-west-2
        aws secretsmanager delete-secret --secret-id odcread-password --force-delete-without-recovery --region us-west-2
        aws secretsmanager delete-secret --secret-id odc-password --force-delete-without-recovery --region us-west-2
        aws secretsmanager delete-secret --secret-id pachyderm-password --force-delete-without-recovery --region us-west-2

        # Remove the secrets from the state file
        terraform state rm module.resources.aws_secretsmanager_secret.stacread_password
        terraform state rm module.resources.aws_secretsmanager_secret.db_password
        terraform state rm module.resources.aws_secretsmanager_secret.argo_password
        terraform state rm module.resources.aws_secretsmanager_secret.grafana_password
        terraform state rm module.resources.aws_secretsmanager_secret.jupyterhub_password
        terraform state rm module.resources.aws_secretsmanager_secret.stac_password
        terraform state rm module.resources.aws_secretsmanager_secret.odcread_password
        terraform state rm module.resources.aws_secretsmanager_secret.odc_password
        terraform state rm module.resources.aws_secretsmanager_secret.pachyderm_password

        terraform apply -destroy -auto-approve
    else
        # Remove the bucket from the state file
        terraform state rm module.resources.aws_s3_bucket.public

         # Remove the database from the state file
        terraform state rm module.resources.module.db.module.db_instance.aws_db_instance.this[0]

        # Remove the secrets from the state file
        terraform state rm module.resources.aws_secretsmanager_secret.stacread_password
        terraform state rm module.resources.aws_secretsmanager_secret.db_password
        terraform state rm module.resources.aws_secretsmanager_secret.argo_password
        terraform state rm module.resources.aws_secretsmanager_secret.grafana_password
        terraform state rm module.resources.aws_secretsmanager_secret.jupyterhub_password
        terraform state rm module.resources.aws_secretsmanager_secret.jodc_password
        terraform state rm module.resources.aws_secretsmanager_secret.stac_password
        terraform state rm module.resources.aws_secretsmanager_secret.odcread_password
        terraform state rm module.resources.aws_secretsmanager_secret.odc_password
        terraform state rm module.resources.aws_secretsmanager_secret.pachyderm_password

        terraform apply -destroy -auto-approve
fi

