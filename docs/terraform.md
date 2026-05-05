# Terraform実験メモ

## 基本方針
- aws-iaを使うというのがおそらく世間的には主流であり、使わないのは車輪の再発明と批判される部類である可能性がある
- その一方で、モジュール化の考えた方自体が一連のリソースのボックス化を過剰に適用しやすく、レビュアーの負担(各aws-iaの知識が必要)やガバナンスの観点で見れば、AWS Providerの直接利用とモジュール化を抑えた記述をするというのも理にかなっていると考える
- 今回の検証では後者の考え方に沿って、各環境を構築する

## 使い方

### (1) Hub環境の構築
- ディレクトリ: [`<root>/hub`](../hub/)

#### 手順１ - backend設定ファイルの作成
[`backend.s3.config.sample`](../hub/backend.s3.config.sample)を**コピーし**、ファイル`backend.s3.config`を作成します
```shell
cp ./backend.s3.config.sample ./backend.s3.config
```

### 手順２ - backend設定の記入
手順１で作成した`backend.s3.config`を開き、以下の変数の値を設定します。
| 変数名 | 内容 | 設定例 |
| --- | --- | --- |
| `bucket` | Terraformステートファイルを格納するバケット名 | `terraform-states` |
| `region` | バケットが存在するAWSリージョン | `ap-northeast-1` |
| `key` | Terraformステートファイルのキー名 | `hub.tfstata` |


#### 手順３ - terratermワーキングディレクトリの初期化
次のコマンドを実行し、terraformワーキングディレクトリの初期化を実行します。
```shell
terraform init -backend-conig=./backend.s3.config
```

#### 手順４ - 環境設定ファイルの作成
[`terraform.tfvars.sample`](../hub/terraform.tfvars.sample)を**コピーし**、ファイル`terraform.tfvars`を作成します
```shell
cp ./terraform.tfvars.sample ./terraform.tfvars
```

#### 手順５ - 設定値の記入
手順４で作成した`terraform.tfvars`を開き、以下の変数の値を設定します。
| 変数名 | 内容 | 設定例 |
| --- | --- | --- |
| `aws_application_arn` | AWS myApplicationのARN | `arn:aws:resource-groups:ap-northeast-1:999999999999:group/bosporus/XXXXXXXXXXXXXXXXXXXXXXXXXX` |
| `flow_log_role_arn` | フローログを作成するためのIAMロールARN | `arn:aws:iam::999999999999:role/VpcFlowLogRole` |

#### 手順６ - レビュー
`plan`を実行し、作成されるリソースの内容をレビューします。
```shell
terraform plan
```

#### 手順７ - 構築
`apply`を実行し、リソースを作成します。
```shell
terraform apply
```

### (2) Spoke環境の構築
- ディレクトリ: [`<root>/spokevpc-marmara`](../spokevpc-marmara/)

#### 手順１ - backend設定ファイルの作成
[`backend.s3.config.sample`](../spokevpc-marmara/backend.s3.config.sample)を**コピーし**、ファイル`backend.s3.config`を作成します
```shell
cp ./backend.s3.config.sample ./backend.s3.config
```

### 手順２ - backend設定の記入
手順１で作成した`backend.s3.config`を開き、以下の変数の値を設定します。
| 変数名 | 内容 | 設定例 |
| --- | --- | --- |
| `bucket` | Terraformステートファイルを格納するバケット名 | `terraform-states` |
| `region` | バケットが存在するAWSリージョン | `ap-northeast-1` |
| `key` | Terraformステートファイルのキー名 | `spokevpc-marmara.tfstata` |


#### 手順３ - terratermワーキングディレクトリの初期化
次のコマンドを実行し、terraformワーキングディレクトリの初期化を実行します。
```shell
terraform init -backend-conig=./backend.s3.config
```

#### 手順４ - 環境設定ファイルの作成
[`terraform.tfvars.sample`](../spokevpc-marmara/terraform.tfvars.sample)を**コピーし**、ファイル`terraform.tfvars`を作成します
```shell
cp ./terraform.tfvars.sample ./terraform.tfvars
```

#### 手順５ - 設定値の記入
手順４で作成した`terraform.tfvars`を開き、以下の変数の値を設定します。
| 変数名 | 内容 | 設定例 |
| --- | --- | --- |
| `aws_application_arn` | AWS myApplicationのARN | `arn:aws:resource-groups:ap-northeast-1:999999999999:group/bosporus/XXXXXXXXXXXXXXXXXXXXXXXXXX` |
| `flow_log_role_arn` | フローログを作成するためのIAMロールARN | `arn:aws:iam::999999999999:role/VpcFlowLogRole` |
| `tgw_id` | 接続するTransit GatewayのID | `tgw-XXXXXXXXXXXXXXXXX` |

> [!TIP]
> Transit Gateway IDはHub構築時のアウトプットとして表示されたものを指定します。

#### 手順６ - レビュー
`plan`を実行し、作成されるリソースの内容をレビューします。
```shell
terraform plan
```

#### 手順７ - 構築
`apply`を実行し、リソースを作成します。
```shell
terraform apply
```

### (3) HubとSpoke VPCの接続
- ディレクトリ: [`<root>/hub`](../hub/)

#### 手順１ - Spoke VPC設定値の記入
`terraform.tfvars`を開き、変数`spoke_vpcs`に接続するSpoke VPCの設定値を記入します。
| 変数名 | 内容 | 設定例 |
| --- | --- | --- |
| `spoke_vpcs.<KEY>` | Spoke VPCの識別名 | `marmara` |
| `spoke_vpcs.<KEY>.vpc_id` | VPC ID | `vpc-XXXXXXXXXXXXXXXXX` |
| `spoke_vpcs.<KEY>.ipv4_cidr_block` | IPv4 CIDRブロック | `10.0.0.0/16` |
| `spoke_vpcs.<KEY>.ipv6_cidr_block` | IPv6 CIDRブロック | `2001:0db8:1:1::/56` |
| `spoke_vpcs.<KEY>.vpc_id` | Transit Gateway Attachment ID | `tgw-attach-XXXXXXXXXXXXXXXXX` |

> [!TIP]
> 各項目はSpoke VPC構築時のアウトプットとして表示されたものを指定します。

記入例
```hcl
spoke_vpcs = {
  "marmara" = {
    vpc_id            = "vpc-XXXXXXXXXXXXXXXXX"
    ipv4_cidr_block   = "10.0.0.0/16"
    ipv6_cidr_block   = "2001:0db8:1:1::/56"
    tgw_attachment_id = "tgw-attach-XXXXXXXXXXXXXXXXX"
  }
}
```

#### 手順２ - レビュー
`plan`を実行し、作成されるリソースの内容をレビューします。
```shell
terraform plan
```

#### 手順３ - 構築
`apply`を実行し、リソースを作成します。
```shell
terraform apply
```

