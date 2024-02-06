# Deploying with GitHub Actions

## Bootstrapping

To connect the GitHub Actions with an Azure subscription:

1. Create a service principal and **make sure to save the output**

   ```bash
   az ad sp create-for-rbac \
     --name "sp-github-actions" \
     --role Owner \
     --scopes /subscriptions/00000000-0000-0000-0000-000000000000 \  # Replace with your subscription ID
     --sdk-auth
   ```

1. Add the output as a GitHub secret named `AZURE_CREDENTIALS`
