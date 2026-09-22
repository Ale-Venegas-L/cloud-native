// Configuración OIDC + API Gateway. Completa con los valores de 'terraform output -raw config_js'.
window.APP_CONFIG = {
  region: 'us-east-1',
  userPoolId: 'us-east-1_XXXXXXXXX',
  clientId: 'xxxxxxxxxxxxxxxxxxxxxxxxxx',
  hostedUiDomain: 'TU_PREFIX_UNICO',         // ej. cloud-native-juan-123
  apiGatewayUrl: 'https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com',
  redirectUri: 'https://dXXXXXXXXXXXXX.cloudfront.net/',  // dominio CloudFront
  scopes: ['openid', 'email', 'profile'],
};
