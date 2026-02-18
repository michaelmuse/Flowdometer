OAuthController oc = new OAuthController();
string sid = oc.getToken();
Assert.isNotNull(sid);
Assert.isTrue(sid.startsWith(UserInfo.getOrganizationId().substring(0, 15)));

HttpRequest request = new HttpRequest();
request.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v55.0/limits/');
request.setMethod('GET');
request.setHeader('Authorization', 'Bearer ' + sid);

HttpResponse response = new Http().send(request);
Assert.areEqual(200, response.getStatusCode());
System.debug(response.getBody());