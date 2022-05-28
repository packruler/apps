# traefik

![Version: 12.0.2](https://img.shields.io/badge/Version-12.0.2-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 2.6.7](https://img.shields.io/badge/AppVersion-2.6.7-informational?style=flat-square)

Traefik is a flexible reverse proxy and Ingress Provider.

**Homepage:** <https://github.com/truecharts/apps/tree/master/charts/core/traefik>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| TrueCharts | info@truecharts.org | https://truecharts.org |

## Source Code

* <https://github.com/traefik/traefik>
* <https://github.com/traefik/traefik-helm-chart>
* <https://traefik.io/>

## Requirements

Kubernetes: `>=1.16.0-0`

| Repository | Name | Version |
|------------|------|---------|
| https://library-charts.truecharts.org | common | 9.3.19 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| additionalArguments | list | `["--metrics.prometheus","--ping","--serverstransport.insecureskipverify=true","--providers.kubernetesingress.allowexternalnameservices=true"]` | Additional arguments to be passed at Traefik's binary All available options available on https://docs.traefik.io/reference/static-configuration/cli/ |
| globalArguments[0] | string | `"--global.checknewversion"` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.repository | string | `"tccr.io/truecharts/traefik"` |  |
| image.tag | string | `"v2.6.7@sha256:f3cd9f39d025da2edbd59d119ea982b75c859f48252075bc2882aeac089dc905"` |  |
| ingressClass | object | `{"enabled":false,"fallbackApiVersion":"","isDefaultClass":false}` | Use ingressClass. Ignored if Traefik version < 2.3 / kubernetes < 1.18.x |
| ingressRoute | object | `{"dashboard":{"annotations":{},"enabled":true,"labels":{}}}` | Create an IngressRoute for the dashboard |
| logs | object | `{"access":{"enabled":false,"fields":{"general":{"defaultmode":"keep","names":{}},"headers":{"defaultmode":"drop","names":{}}},"filters":{},"format":"common"},"general":{"format":"common","level":"ERROR"}}` | Logs https://docs.traefik.io/observability/logs/ |
| logs.access.format | string | `"common"` | Set the format of Access Logs to be either Common Log Format or JSON. For more information: https://doc.traefik.io/traefik/observability/access-logs/#format |
| logs.general.format | string | `"common"` | Set the format of General Logs to be either Common Log Format or JSON. For more information: https://doc.traefik.io/traefik/observability/logs/#format |
| metrics.prometheus.entryPoint | string | `"metrics"` |  |
| middlewares | object | `{"basicAuth":[],"chain":[],"forwardAuth":[],"ipWhiteList":[],"rateLimit":[],"redirectRegex":[],"redirectScheme":[],"stripPrefixRegex":[]}` | SCALE Middleware Handlers |
| pilot | object | `{"enableThemePark":false,"enabled":false,"token":""}` | Activate Pilot integration |
| podAnnotations."prometheus.io/path" | string | `"/metrics"` |  |
| podAnnotations."prometheus.io/port" | string | `"9180"` |  |
| podAnnotations."prometheus.io/scrape" | string | `"true"` |  |
| portalhook.enabled | bool | `true` |  |
| probes.liveness | object | See below | Liveness probe configuration |
| probes.liveness.path | string | "/" | If a HTTP probe is used (default for HTTP/HTTPS services) this path is used |
| probes.liveness.type | string | "TCP" | sets the probe type when not using a custom probe |
| probes.readiness | object | See below | Redainess probe configuration |
| probes.readiness.path | string | "/" | If a HTTP probe is used (default for HTTP/HTTPS services) this path is used |
| probes.readiness.type | string | "TCP" | sets the probe type when not using a custom probe |
| probes.startup | object | See below | Startup probe configuration |
| probes.startup.path | string | "/" | If a HTTP probe is used (default for HTTP/HTTPS services) this path is used |
| probes.startup.type | string | "TCP" | sets the probe type when not using a custom probe |
| providers | object | `{"kubernetesCRD":{"enabled":true,"namespaces":[]},"kubernetesIngress":{"enabled":true,"namespaces":[],"publishedService":{"enabled":true}}}` | Configure providers |
| rbac | object | `{"enabled":true,"rules":[{"apiGroups":[""],"resources":["services","endpoints","secrets"],"verbs":["get","list","watch"]},{"apiGroups":["extensions","networking.k8s.io"],"resources":["ingresses","ingressclasses"],"verbs":["get","list","watch"]},{"apiGroups":["extensions","networking.k8s.io"],"resources":["ingresses/status"],"verbs":["update"]},{"apiGroups":["traefik.containo.us"],"resources":["ingressroutes","ingressroutetcps","ingressrouteudps","middlewares","middlewaretcps","tlsoptions","tlsstores","traefikservices","serverstransports"],"verbs":["get","list","watch"]}]}` | Whether Role Based Access Control objects like roles and rolebindings should be created |
| service | object | `{"main":{"ports":{"main":{"forwardedHeaders":{"enabled":false},"port":9000,"protocol":"HTTP","targetPort":9000}},"type":"LoadBalancer"},"metrics":{"enabled":true,"ports":{"metrics":{"enabled":true,"forwardedHeaders":{"enabled":false},"port":9180,"protocol":"HTTP","targetPort":9180}},"type":"ClusterIP"},"tcp":{"enabled":true,"ports":{"web":{"enabled":true,"forwardedHeaders":{"enabled":false,"insecureMode":false,"trustedIPs":[]},"port":9080,"protocol":"HTTP","redirectTo":"websecure"},"websecure":{"enabled":true,"forwardedHeaders":{"enabled":false,"insecureMode":false,"trustedIPs":[]},"port":9443,"protocol":"HTTPS"}},"type":"LoadBalancer"},"udp":{"enabled":false}}` | Options for the main traefik service, where the entrypoints traffic comes from from. |
| service.main.ports.main.forwardedHeaders | object | `{"enabled":false}` | Forwarded Headers should never be enabled on Main entrypoint |
| service.metrics.ports.metrics.forwardedHeaders | object | `{"enabled":false}` | Forwarded Headers should never be enabled on Metrics entrypoint |
| service.tcp.ports.web.forwardedHeaders | object | `{"enabled":false,"insecureMode":false,"trustedIPs":[]}` | Configure (Forwarded Headers)[https://doc.traefik.io/traefik/routing/entrypoints/#forwarded-headers] Support |
| service.tcp.ports.web.forwardedHeaders.insecureMode | bool | `false` | Trust all forwarded headers |
| service.tcp.ports.web.forwardedHeaders.trustedIPs | list | `[]` | List of trusted IP and CIDR references |
| service.tcp.ports.websecure.forwardedHeaders | object | `{"enabled":false,"insecureMode":false,"trustedIPs":[]}` | Configure (Forwarded Headers)[https://doc.traefik.io/traefik/routing/entrypoints/#forwarded-headers] Support |
| service.tcp.ports.websecure.forwardedHeaders.insecureMode | bool | `false` | Trust all forwarded headers |
| service.tcp.ports.websecure.forwardedHeaders.trustedIPs | list | `[]` | List of trusted IP and CIDR references |
| serviceAccount | object | `{"create":true}` | The service account the pods will use to interact with the Kubernetes API |
| tlsOptions | object | `{"default":{"cipherSuites":["TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256","TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384","TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305","TLS_AES_128_GCM_SHA256","TLS_AES_256_GCM_SHA384","TLS_CHACHA20_POLY1305_SHA256"],"curvePreferences":["CurveP521","CurveP384"],"minVersion":"VersionTLS12","sniStrict":false}}` | TLS Options to be created as TLSOption CRDs https://doc.traefik.io/tccr.io/truecharts/https/tls/#tls-options Example: |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.7.0](https://github.com/norwoodj/helm-docs/releases/v1.7.0)
