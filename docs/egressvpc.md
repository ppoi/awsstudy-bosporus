# Egress VPC実験メモ

## 環境

- リージョン: ap-northeast-1(Tokyo)
- Availability Zone:
  - A: ap-northeast-1c
  - B: ap-northeast-1d

### 構成図
![Architecture Diagram](../docs/architecture.drawio.svg)

- Egress VPCとSpoke VPCを作成
- Transit Gateway Attachmentは、それぞれのVPCにおいて専用のサブネットを作成して接続する
- Egress VPC TGW Attachmentを関連付けるTransit Gatewayルートテーブルを1個作成し、各Spoke VPCのTGW Attachmentからルートテーブルプロパゲーションが行われるよう設定する
- 各Spoke VPCのTGW Attachmentを関連付けるTransit Gatewayルートテーブルを1個作成し(1:n)、IPv4およびNAT64のデフォルトルートをEgress VPCに向けるルートを設定する
  - 最初はルートテーブルプロパゲーションは設定しない(Spoke VPC間通信をしない)

### アドレス空間
- Egress VPC
  - IPv4: 192.168.0.0/16
  - IPv6: 2406:da14:ce5:600::/56
- Spoke VPC(marmara)
  - IPv4: 10.0.0.0/16
  - IPv6: 2406:da14:86c:7800::/56

### ルートテーブル
#### VPCルートテーブル
**Egress VPC / Public Subnet[1]**
| Destination | ターゲット |
| --- | --- |
| 192.168.0.0/16 | local |
| 2406:da14:ce5:600::/56 | local |
| 0.0.0.0/0 | Internet Gateway |
| ::0/0 | Egress only IGW |
| 10.0.0.0/16 | Egress VPC TGW Attachment |
| 2406:da14:86c:7800::/56 | Egress VPC TGW Attachment |

**Egress VPC / TGW Subnet[2A]**
| Destination | ターゲット |
| --- | --- |
| 192.168.0.0/16 | local |
| 2406:da14:ce5:600::/56 | local |
| 0.0.0.0/0 | NAT Gateway[A] |
| 64:ff9b::/96 | NAT Gateway[A] |

**Egress VPC / TGW Subnet[2B]**
| Destination | ターゲット |
| --- | --- |
| 192.168.0.0/16 | local |
| 2406:da14:ce5:600::/56 | local |
| 0.0.0.0/0 | NAT Gateway[B] |
| 64:ff9b::/96 | NAT Gateway[B] |

**Spoke VPC / Application Subnet(4)**
| Destination | ターゲット |
| --- | --- |
| 192.168.0.0/16 | local |
| 2406:da14:ce5:600::/56 | local |
| ::/0 | Spoke VPC Egress-only IGW |
| 0.0.0.0/0 | Spoke VPC TGW Attachment |
| 64:ff9b::/96 | Spoke VPC TGW Attachment |

**Spoke VPC / TGW Subnet(3A, 3B)**
| Destination | ターゲット |
| --- | --- |
| 192.168.0.0/16 | local |
| 2406:da14:ce5:600::/56 | local |

#### Transit Gatewayルートテーブル

**Egress**
| Destination | ターゲット | action |
| --- | --- | --- |
| 10.0.0.0/16 | Spoke VPC | porpagation |
| 2406:da14:14fd:5000::/56 | Spoke VPC | porpagation |

**Spoke VPCs**
| Destination | ターゲット | action |
| --- | --- |
| ::/0 | Egress VPC | manual |
| 64:ff9b::/96 | Egress VPC | manual |


## 疎通確認

### 方式
- Spoke VPCの各サブネット上のリソース(EC2インスタンス, CloudShell)から外部サイトへのHTTPS通信が疎通することを確認する
- IPv4, NAT64での通信は、Transit Gatewayを経由してEgress VPCのNAT Gateway, IGWを通して疎通することを確認する
- IPv6での通信は、Spoke VPCのEgress only IGWを通して疎通することを確認する

### 結果

| 接続元 | ターゲット | 結果 | メモ |
| --- | --- | --- | --- |
| Bastion(dualstack) | SSM | OK | フリートマネージャにも登録され、aws ssm start-sessionでの接続もOK |
| Bastion(dualstack) | https://wwww.google.com | OK | `curl -sv6`でIPv6での疎通を確認 |
| Bastion(dualstack) | https://imas.gamedbs.jp/cgss/ | OK | `curl -sv4`でIPv4での疎通を確認 |
| Bastion(dualstack) | https://imas.gamedbs.jp/cgss/ | OK | `curl -sv6`でNAT64での疎通を確認 |
| Bastion(dualstack) | Bastion(IPv6 only) | OK | sshでログインできることを確認 |
| Bastion(IPv6 only) | https://wwww.google.com | OK | `curl -sv`でIPv6での疎通を確認 |
| Bastion(IPv6 only) | https://imas.gamedbs.jp/cgss/ | OK | `curl -sv`でNAT64での疎通を確認 |
| CloudShell | https://imas.gamedbs.jp/cgss/ | OK | `curl -sv`でIPv4での疎通を確認 |


## 料金について
- [Amazon VPC の料金](https://aws.amazon.com/jp/vpc/pricing/)
- [AWS Transit Gateway の料金](https://aws.amazon.com/jp/transit-gateway/pricing/)

- Transit Gatewayの設置自体に料金はかからない
- アタッチメント毎の設置時間: $0.07/hour
- 通信量: $0.02/GB

- Transit Gateway
  - 設置: アタッチメント毎に $0.07/hour
  - 通信量: $0.02/GB
- NAT Gateway
  - 設置: $0.068/hour
  - 通信量: $0.062/GB

VPCあたり$50.4(0.07 * 24 * 30)/month。

NAT Gatewayが$97.92(0.068 * 2 * 24 * 30)/month


## aws-ia/vpc

- main vpc
- public subnet
  - ルートテーブルはサブネット毎に作られている
    - 0.0.0.0/0 to IGW
    - ::/0 to Egress-only IGW
    - TGWのルーティング(var.transit_gateway_routes["public"])
  - NAT Gateway
    - AZごと=サブネットごと
    - NAT GatewayごとにElastic IP
- private subnet
  - ルートテーブルはサブネット毎
    - 0.0.0.0/0 to NAT Gateway
    - ::/0 to Egress-only IGW
    - TGWのルーティング(local.private_subnet_key_names_tgw_routed)
- tgw subnet
  - AZごと
    - az, vpc_id, cidr_blockのみ指定
      - そういやDNS64は？
  - ルートテーブルはサブネット毎
    - 0.0.0.0/0 to NAT Gateway ?
- transit gateway attachment
  - tgw subnet
- IGW
- Egress-only IGW

## aws-ia/hubandspoke

- Transit Gateway
- Central VPC
  - Inspection
  - Egress
- TGW Route Table(central VPCs)
  - local.associate_and_propagate_to_tgwぶんだけ
    - egress
      - public: var.network_Definition.value
  - 各Central VPCのattachmentと1:1関連付け
- TGW Route Table(Spoke VPCs)
  - for_each local.routing_domains
  - association: 各Spoke VPCのattachmentと1:1関連付け
  - prpagation: spoke to spokeの場合。いったん置いておく。
  - 0.0.0.0/0 to Egress VPC attachment
    - ::/0 はいらんのか？
- TGW RT propagation
  - Inspection VPCなしでEgress VPCあり or 両方あって全トラフィックinspection or 中東
  - spokeのアタッチメントをEgress VPCのTGW RT
