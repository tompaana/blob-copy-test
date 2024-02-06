# Deploying with GitHub Actions

## Bootstrapping

To connect the GitHub Actions with an Azure subscription:

1. Create a service principal and **make sure to save the output**

   ```bash
   az ad sp create-for-rbac \
     --name "sp-github-actions" \
     --role Contributor \
     --scopes /subscriptions/00000000-0000-0000-0000-000000000000 \  # Replace with your subscription ID
     --sdk-auth
   ```

   > The scope can also be limited to a resource group level. For more information, see [Use the Azure login action with a service principal secret](https://learn.microsoft.com/azure/developer/github/connect-from-azure?tabs=azure-cli%2Cwindows#use-the-azure-login-action-with-a-service-principal-secret).

1. Add the output as a GitHub secret named `AZURE_CREDENTIALS`
