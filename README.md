# Azure CycleCloud template for ioChem-BD and Solovers

[Azure CycleCloud](https://docs.microsoft.com/en-us/azure/cyclecloud/) はMicrosoft Azure上で簡単にCAE/HPC/Deep Learning用のクラスタ環境を構築できるソリューションです。

Azure CyceCloudのインストールに関しては、[こちら](https://docs.microsoft.com/en-us/azure/cyclecloud/quickstart-install-cyclecloud) のドキュメントを参照してください。

## テンプレート詳細
ioChem-BD用のテンプレートになっています。
以下の構成、特徴を持っています。

1. Slurmジョブスケジューラをschedulerノードにインストール
1. H16r, H16r_Promo, HC44rs, HB60rs, HB120rs_v2などソルバー利用を想定した設定
         - OpenLogic CentOS 7.6 HPC を利用 
1. NFS設定されており、ホームディレクトリが永続ディスク設定。Executeノード（計算ノード）からNFSをマウント
1. MasterノードのIPアドレスを固定設定
         - 一旦停止後、再度起動した場合にアクセスする先のIPアドレスが変更されない
1. 対応ソルバ
         - Quantum ESPRESSO 6.4.1, 6.5, 6.6
         - RSM RISM Quantum ESPRESOO 6.1ベース
         - GROMACS 2018, 2019, 2020
         - LAMMPS stable_7Aug2019
    stable_3Mar2020, stable_29Oct2020 
         - NAMD
         - GAMESS (対応中)

## テンプレートインストール方法

**前提条件:** テンプレートを利用するためには、Azure CycleCloud CLIのインストールと設定が必要です。詳しくは、 [こちら](https://docs.microsoft.com/en-us/azure/cyclecloud/install-cyclecloud-cli) の文書からインストールと展開されたAzure CycleCloudサーバのFQDNの設定が必要です。

1. テンプレート本体をダウンロード
1. 展開、ディレクトリ移動
1. cyclecloudコマンドラインからテンプレートインストール 
   - tar zxvf cyclecloud-iochembd<version>.tar.gz
   - /blobディレクトリにGAMESSやNAMDなどソースコード、およびバイナリを設定します。
   - cd cyclecloud-iochembd<version>
   - cyclecloud project upload cyclecloud-storage
   - cyclecloud import_template -f templates/slurm-iochembd-nfs.txt
1. 削除したい場合、 cyclecloud delete_template ioChem-BD コマンドで削除可能

***
Copyright Hiroshi Tanaka, hirtanak@gmail.com, @hirtanak All rights reserved.
Use of this source code is governed by MIT license that can be found in the LICENSE file.
