// Configuración OIDC + API Gateway. Completa con los valores de 'terraform output -raw config_js'.
window.APP_CONFIG = {
  region: 'us-east-1',
  userPoolId: 'us-east-1_BMBu6dCFz',
  clientId: '4423ear0qltdu9f6fu9v1uigqq',
  hostedUiDomain: 'cloud-native-b1b48e40',
  apiGatewayUrl: 'https://4aiivtsw60.execute-api.us-east-1.amazonaws.com',
  redirectUri: 'https://ec2-44-203-131-227.compute-1.amazonaws.com/',
  scopes: ['openid', 'email', 'profile'],
};
