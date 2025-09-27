import file

schema composition:
    _clusterName: str
    _clusterProvider: str
    _source: str
    _group: str
    _version: str
    _kind: str
    apiVersion = "apiextensions.crossplane.io/v1"
    kind = "Composition"
    metadata = {
        labels = {
            cluster = _clusterName
            provider = _clusterProvider
        }
        name = "{}.{}.{}".format(_clusterName, _clusterProvider, _group)
    }
    spec = {
        compositeTypeRef = {
            apiVersion = "{}/{}".format(_group, _version)
            kind = _kind
        }
        mode = "Pipeline"
        pipeline = [
            {
                step = _clusterProvider
                functionRef.name = "crossplane-contrib-function-kcl"
                input = {
                    apiVersion = "krm.kcl.dev/v1alpha1"
                    kind = "KCLRun"
                    spec.source = _source
                }
            }
            {
                step = "automatically-detect-ready-composed-resources"
                functionRef.name = "crossplane-contrib-function-auto-ready"
            }
        ]
        writeConnectionSecretsToNamespace = "crossplane-system"
    }

[
    composition {
        _group = "platform-engineering.dylanmoore.dev"
        _version = "v1alpha1"
        _kind = "Cluster"
        _clusterName = "gke-autopilot"
        _clusterProvider = "google"
        _source = file.read("kcl/gke-autopilot.k")
    }
]
