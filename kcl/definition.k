apiVersion = "apiextensions.crossplane.io/v2"
kind = "CompositeResourceDefinition"
metadata = {
    name = "clusters.platform-engineering.dylanmoore.dev"
}
spec = {
    group = "platform-engineering.dylanmoore.dev"
    names = {
        kind = "Cluster"
        plural = "clusters"
    }
    scope = "Namespaced"
    versions = [
        {
            name = "v1alpha1"
            served = True
            referenceable = True
            schema = {
                openAPIV3Schema = {
                    type = "object"
                    properties = {
                        spec = {
                            type = "object"
                            required = ["name"]
                            properties = {
                                name.type = "string"
                                location = {
                                    type = "string"
                                    default = "us-west1"
                                }
                                clusterDeletionProtection = {
                                    type = "boolean"
                                    default = True
                                }
                                providerConfigName = {
                                    type = "string"
                                    default = "default"
                                }
                                deletionPolicy = {
                                    type = "string"
                                    enum = [
                                        "Delete"
                                        "Orphan"
                                    ]
                                    default = "Delete"
                                }
                            }
                        }
                    }
                }
            }
        }
    ]
}
