# Manually created secerets

Manual secrets are external, one-off secrets that can't be generated
in Terraform.

## List of secrets

Secrets need to be made in each environment manually.

Jupyterhub OAuth:

``` bash
aws secretsmanager create-secret \
    --name hub-client-secret \
    --secret-string LONGSTRINGHERE \
    --region us-west-2
```

Argo OAuth:

``` bash
aws secretsmanager create-secret \
    --name argo-client-and-secret \
    --secret-string CLIENT:SECRET \
    --region us-west-2
```

Grafana OAuth

``` bash
aws secretsmanager create-secret \
    --name grafana-client-and-secret \
    --secret-string CLIENT:SECRET \
    --region us-west-2
```

Slack for Flux

``` bash
aws secretsmanager create-secret \
    --name flux-webhook \
    --secret-string EXAMPLELONGSTRING \
    --region us-west-2
```
