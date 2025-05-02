data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

module "ebs_csi_irsa_role" {
  source                = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name             = "${local.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.33"

  cluster_name                   = local.cluster_name
  cluster_version                = var.eks-version
  cluster_endpoint_public_access = true

  # EKS Addons
  cluster_addons = {
    coredns = {
      addon_version = var.coredns-version
      configuration_values = jsonencode({
        computeType = "Fargate"
        autoScaling = {
          enabled     = true
          minReplicas = 4
          maxReplicas = 10
        }
        resources = {
          requests = {
            cpu    = "0.50"
            memory = "256M"
          }
          limits = {
            cpu    = "1.00"
            memory = "512M"
          }
        }
      })
    }
    kube-proxy = {
      addon_version = var.kube-proxy-version
    }
    vpc-cni    = {
      addon_version = var.vpc-cni-version
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Fargate profiles use the cluster primary security group so these are not utilized
  create_cluster_security_group = false
  create_node_security_group    = false

  fargate_profiles = {
    kube_system = {
      selectors = [
        { namespace = "kube-system" }
      ]
    }
    karpenter = {
      selectors = [
        { namespace = "karpenter" }
      ]
    }
    flux = {
      selectors = [
        { namespace = "flux-system" }
      ]
    }
    external_dns = {
      selectors = [
        { namespace = "aws-external-dns-helm" }
      ]
    }
  }

  enable_cluster_creator_admin_permissions = true

  access_entries = {
    admin-access = {
      kubernetes_groups = []
      principal_arn     = var.sso-admin-role-arn

      policy_associations = {
        single = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  tags = merge(local.tags, {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = local.cluster_name
  })
}

# External DNS (magic DNS record creator)
module "external_dns_helm" {
  source  = "lablabs/eks-external-dns/aws"
  version = "1.2"

  enabled           = true
  argo_enabled      = false
  argo_helm_enabled = false

  cluster_identity_oidc_issuer     = module.eks.oidc_provider
  cluster_identity_oidc_issuer_arn = module.eks.oidc_provider_arn

  helm_release_name = "aws-ext-dns-helm"
  namespace         = "aws-external-dns-helm"

  values = yamlencode({
    "LogLevel" : "error"
    "provider" : "aws"
    "registry" : "txt"
    "txtOwnerId" : "eks-cluster"
    "txtPrefix" : "external-dns"
    "policy" : "sync"
    "domainFilters" : [
      var.subdomain
    ]
    "publishInternalServices" : "true"
    "triggerLoopOnEvent" : "true"
    "interval" : "5s"
    "podLabels" : {
      "app" : "aws-external-dns-helm"
    }
  })

  helm_timeout = 240
  helm_wait    = true
}

# Karpenter (magic autoscaler)
module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter" # needs two slashes!

  enable_irsa            = true
  cluster_name           = module.eks.cluster_name
  irsa_oidc_provider_arn = module.eks.oidc_provider_arn

  # Used to attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    AmazonEBSCSIDriverPolicy     = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    AmazonCNIPolicy              = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  }

  tags = local.tags
}

# Karpenter Helm Chart
resource "helm_release" "karpenter" {
  namespace           = "karpenter"
  create_namespace    = true
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "0.37.7"

  values = [
    <<-EOT
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: ${module.karpenter.iam_role_arn}
    controller:
      resources:
        requests:
          cpu: 1
          memory: 2Gi
        limits:
          cpu: 1
          memory: 2Gi
    EOT
  ]
}

# Karpenter nodeclass and nodepool
resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1beta1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: AL2
      role: ${module.karpenter.node_iam_role_name}
      blockDeviceMappings:
      - deviceName: /dev/xvda
        ebs:
          volumeSize: 120Gi
          volumeType: gp3
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1beta1
    kind: NodePool
    metadata:
      name: default
    spec:
      template:
        spec:
          nodeClassRef:
            name: default
          requirements:
            - key: "karpenter.k8s.aws/instance-category"
              operator: In
              values: ["c", "m", "r", "t", "z"]
            - key: "karpenter.k8s.aws/instance-cpu"
              operator: In
              values: ["4", "8", "16", "32", "48", "64", "96", "192"]
            - key: "karpenter.k8s.aws/instance-hypervisor"
              operator: In
              values: ["nitro"]
            - key: "karpenter.k8s.aws/instance-generation"
              operator: Gt
              values: ["2"]
            - key: "kubernetes.io/arch"
              operator: In
              values: ["amd64"]
      limits:
        cpu: 10000
      disruption:
        consolidationPolicy: WhenEmpty
        consolidateAfter: 30s

  YAML
  depends_on = [
    kubectl_manifest.karpenter_node_class
  ]
}

# Specific nodepool for GPU instances
resource "kubectl_manifest" "karpenter_node_pool_gpu" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1beta1
    kind: NodePool
    metadata:
      name: gpu
    spec:
      template:
        spec:
          nodeClassRef:
            name: default
          requirements:
          - key: node.kubernetes.io/instance-type
            operator: In
            values: ["g6.2xlarge", "g5.2xlarge", "g4.2xlarge"]
          taints:
          - key: nvidia.com/gpu
            value: "true"
            effect: NoSchedule
      limits:
        gpu: 30
      disruption:
        consolidationPolicy: WhenUnderutilized

  YAML
  depends_on = [
    resource.kubectl_manifest.karpenter_node_class
  ]
}

output "cluster_endpoint" {
  description = "EKS Cluster Endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS Cluster Name"
  value       = module.eks.cluster_name
}

output "cluster_certificate_authority_data" {
  description = "EKS Cluster Certificate Authority Data"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_oidc_provider_arn" {
  description = "EKS Cluster OIDC Provider ARN"
  value       = module.eks.oidc_provider_arn
}

output "cluster_oidc_issuer_url" {
  description = "EKS Cluster OIDC Issuer URL"
  value       = module.eks.cluster_oidc_issuer_url
}

output "cluster_tls_certificate_sha1_fingerprint" {
  description = "EKS Cluster TLS Certificate SHA1 Fingerprint"
  value       = module.eks.cluster_tls_certificate_sha1_fingerprint
}
