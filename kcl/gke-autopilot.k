import crypto

oxr = option("params").oxr
ocds = option("params").ocds

specObj = oxr.spec or {}
metadataObj = oxr.metadata or {}

metadataName = metadataObj.name
nameHash = crypto.sha256(metadataName)
nameAndHash = "{}-{}".format(metadataName[0:12:], nameHash)

managedResourceName = lambda baseName: str -> str {
    "gke-ap-{}-{}".format(baseName, nameAndHash)[0:45:].rstrip("-")
}

annotations = lambda resourceName: str, additionalAnnotations: any = {} -> any {
    _annotations = {key = value for key, value in additionalAnnotations}

    _annotations["krm.kcl.dev/composition-resource-name"] = resourceName

    _annotations
}

clusterName: str = specObj.name
clusterLocation: str = specObj.location or "us-west1"
providerName: str = specObj.providerConfigName or "default"
clusterDeletionProtection: bool = specObj.clusterDeletionProtection or True
deletionPolicy: str = specObj.deletionPolicy or "Delete"

clusterObjName = managedResourceName("cluster")
serviceAccountObjName = managedResourceName("svc-acct")
serviceAccountKeyObjName = managedResourceName("svc-acct-key")
networkObjName = managedResourceName("network")
subnetworkObjName = managedResourceName("subnetwork")

serviceAccountName = nameAndHash[0:30:].rstrip("-")

observedClusterConnectionDetails = ocds[clusterObjName]?.ConnectionDetails or {}
encodedKubeconfig = observedClusterConnectionDetails.kubeconfig or ""

observedServiceAccountKeyConnectionDetails = ocds[serviceAccountKeyObjName]?.ConnectionDetails or {}
encodedServiceAccountKey = observedServiceAccountKeyConnectionDetails.private_key or ""

connectionDetails = {
    apiVersion: "meta.krm.kcl.dev/v1alpha1"
    kind: "CompositeConnectionDetails"
    data: {
        kubeconfig: encodedKubeconfig
        serviceAccountPrivateKey: encodedServiceAccountKey
    }
}

_resources = [
    connectionDetails
    {
        apiVersion = "compute.gcp.upbound.io/v1beta1"
        kind = "Network"
        metadata = {
            name = networkObjName
            annotations = annotations(networkObjName)
            labels = {
                "network.platform-engineering.dylanmoore.dev/network-id" = networkObjName
            }
        }
        spec = {
            forProvider = {
                autoCreateSubnetworks = False
                routingMode = "REGIONAL"
            }
            providerConfigRef.name = providerName
            deletionPolicy = deletionPolicy
        }
    }
    {
        apiVersion = "compute.gcp.upbound.io/v1beta2"
        kind = "Subnetwork"
        metadata = {
            name = subnetworkObjName
            annotations = annotations(subnetworkObjName)
        }
        spec = {
            forProvider = {
                region = clusterLocation
                networkSelector.matchControllerRef = True
                privateIpGoogleAccess = True
                ipCidrRange = "172.16.0.0/16"
                secondaryIpRange = [
                    {
                        rangeName = "pods"
                        ipCidrRange = "10.200.0.0/14"
                    }
                    {
                        rangeName = "services"
                        ipCidrRange = "10.204.0.0/16"
                    }
                ]
            }
            providerConfigRef.name = providerName
            deletionPolicy = deletionPolicy
        }
    }
]

items = _resources
