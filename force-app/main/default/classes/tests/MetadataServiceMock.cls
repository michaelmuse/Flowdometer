/**
 * @description Web service callout mock for MetadataService tests
 */
@IsTest
public class MetadataServiceMock implements WebServiceMock {
    public void doInvoke(
            Object stub,
            Object request,
            Map<String, Object> response,
            String endpoint,
            String soapAction,
            String requestName,
            String responseNS,
            String responseName,
            String responseType
    ) {
        if (request instanceof MetadataService.retrieve_element)
            response.put(
                    'response_x',
                    new MetadataService.retrieveResponse_element()
            );
        else if (
                request instanceof MetadataService.checkDeployStatus_element
        )
            response.put(
                    'response_x',
                    new MetadataService.checkDeployStatusResponse_element()
            );
        else if (request instanceof MetadataService.listMetadata_element)
            response.put(
                    'response_x',
                    new MetadataService.listMetadataResponse_element()
            );
        else if (
                request instanceof MetadataService.checkRetrieveStatus_element
        )
            response.put(
                    'response_x',
                    new MetadataService.checkRetrieveStatusResponse_element()
            );
        else if (
                request instanceof MetadataService.describeMetadata_element
        )
            response.put(
                    'response_x',
                    new MetadataService.describeMetadataResponse_element()
            );
        else if (request instanceof MetadataService.deploy_element)
            response.put(
                    'response_x',
                    new MetadataService.deployResponse_element()
            );
        else if (request instanceof MetadataService.updateMetadata_element)
            response.put(
                    'response_x',
                    new MetadataService.updateMetadataResponse_element()
            );
        else if (request instanceof MetadataService.renameMetadata_element)
            response.put(
                    'response_x',
                    new MetadataService.renameMetadataResponse_element()
            );
        else if (request instanceof MetadataService.cancelDeploy_element)
            response.put(
                    'response_x',
                    new MetadataService.cancelDeployResponse_element()
            );
        else if (request instanceof MetadataService.deleteMetadata_element)
            response.put(
                    'response_x',
                    new MetadataService.deleteMetadataResponse_element()
            );
        else if (request instanceof MetadataService.upsertMetadata_element)
            response.put(
                    'response_x',
                    new MetadataService.upsertMetadataResponse_element()
            );
        else if (request instanceof MetadataService.createMetadata_element)
            response.put(
                    'response_x',
                    new MetadataService.createMetadataResponse_element()
            );
        else if (
                request instanceof MetadataService.deployRecentValidation_element
        )
            response.put(
                    'response_x',
                    new MetadataService.deployRecentValidationResponse_element()
            );
        else if (
                request instanceof MetadataService.describeValueType_element
        )
            response.put(
                    'response_x',
                    new MetadataService.describeValueTypeResponse_element()
            );
        else if (
                request instanceof MetadataService.checkRetrieveStatus_element
        )
            response.put(
                    'response_x',
                    new MetadataService.checkRetrieveStatusResponse_element()
            );
        return;
    }
}