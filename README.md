# OpenShift Red Hat Subscription entitlement operator

This repo contains a PoC of a tool to automatically entitle an OpenShift cluster. The entitlement manager runs in a pod and can be managed via a Kubernetes Custom Resource.

## Deployment via the operator

1. create a dedicated project where the operator is executed

```
$ oc new-project ocp-entitlement-manager-operator
```

**IMPORTANT:** if you use a different project name you will need to edit the `ClusterRoleBinding` mainifest

2. create the CRD

```
$ oc create -f https://github.com/pbertera/ocp-entitlement-manager/raw/master/operator/deploy/crds/entitlement-manager.bertera.it_entitlements_crd.yaml
```

3. create the role and rolebindings (if you are using a custom namespace to deploy the operator please modify the namespace of the `ClusterRoleBinding` `ServiceAccount`

```
$ oc create -f https://github.com/pbertera/ocp-entitlement-manager/raw/master/operator/deploy/role.yaml
$ oc create -f https://github.com/pbertera/ocp-entitlement-manager/raw/master/operator/deploy/role_binding.yaml
```

4. apply the `CustomResource` quota

```
$ oc create -f https://github.com/pbertera/ocp-entitlement-manager/raw/master/operator/deploy/quota.yaml
```

5. deploy the operator

```
$ oc create -f https://github.com/pbertera/ocp-entitlement-manager/raw/master/operator/deploy/operator.yaml
```

Now the operator is installed, you can check the deployment and the controlled pods:

```
$ oc describe deployment ocp-entitlement-manager-operator
$ oc get pods # should return a pod with name entitlement-manager-xxxx
```

6. create the secret: you have to get the token from [https://cloud.redhat.com/openshift/token](https://cloud.redhat.com/openshift/token)

```
$ oc create secret generic ocm-token --from-literal=ocm-token.json="eyJ...."
```

7. create the `Entitlement` custom resource:

```
$ cat <<EOF | oc create -f -
apiVersion: "entitlement-manager.bertera.it/v1alpha1"
kind: "Entitlement"
metadata:
  name: "cluster-entitlement"
spec:
  ocmTokenSecret: "ocm-token"
  loopHours: 1
  supportLevel: "Self-Support"
  usage: "Production"
```

8. check the entitlment

```
$ oc get entitlement
NAME                  SUPPORT        USAGE
cluster-entitlement   Self-Support   Production
```

After creating the `Entitlement` a new deployment named `entitlement-manager` will be created. This deployment controls a pod running the manager.
In case there is a mismatch between the `Entitlement` and the entitlement assigned to the cluster the manager will try to apply the values of the `Entitlement` in case of a failure the controlled pod will exits.
Checking the pod logs should help troubleshooting the issue


### Entitlment specs

- `supportLevel`: (string) valid values: `Self-Support`, `Eval`, `Standard`, `Premium`, `None`
- `usage`: (string) valid values: `Production`, `Development/Test`, `Disaster Recovery`, `Academic`
- `ocmTokenSecret`: (string) the name of the secret containing the cloud.redhat.com token, the key name must be `ocm-token.json`
- `loopHours`: (string) interval in hours between entitlements check
- `clusterUUID`: (string) the OpenShif cluster UUID, if not defined the operator will gather the UUID from the API (here the reason for the ClusterRole)

## Deployment in a static pod

TODO

## Resources

- [OpenShift Account Management Service API](https://api.openshift.com/?urls.primaryName=Accounts%20management%20service)
- [ocm-cli](https://github.com/openshift-online/ocm-cli)
- [Operator SDK](https://sdk.operatorframework.io/)
