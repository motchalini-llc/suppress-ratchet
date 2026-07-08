# Suppress Ratchet

リンターの抑制コメント（`eslint-disable` / `biome-ignore` / Python の `# noqa` /
`# pylint: disable`）が新しく増えたら PR を落とす、ゼロ依存の GitHub Action。
composite action（`action.yml`）＋1本の bash スクリプト（`gate.sh`）だけで構成され、
抑制コメントの件数をベースラインと比較し、増えていれば失敗・インライン注釈を出す
「ラチェット」ゲート。型の逃げ道（`any` 等）を扱う Type Ratchet と二重カウントしない
よう役割分担している。type/test/suppress の3兄弟アクション（Ratchet family）の3本目
で、GitHub Marketplace に公開済み。

## ループ運用（/goal）

「条件を満たすまで自動で回す」作業には `/goal` を使う（/goal・/loop・/schedule の
使い分けの全体像はグローバルの PLAYBOOK §7 を参照）。条件は
**測定可能な終了状態＋証明方法＋ターン上限**の3点セットで書く。

### 標準完了条件（このリポジトリの証明方法）

このリポジトリに単体テストランナーはなく、ゲート本体（`gate.sh`）を
`tests/fixtures/{typescript,python}-{clean,dirty}` に対して実際に実行して確認する。

| チェック | コマンド | 合格条件 |
|---|---|---|
| clean fixture でゲートが通る（TypeScript） | `INPUT_LANGUAGE=typescript INPUT_WORKING_DIRECTORY=tests/fixtures/typescript-clean bash gate.sh` | exit 0 |
| dirty fixture でゲートが落ちる（TypeScript） | `INPUT_LANGUAGE=typescript INPUT_WORKING_DIRECTORY=tests/fixtures/typescript-dirty bash gate.sh` | exit 非0（1） |
| clean fixture でゲートが通る（Python） | `INPUT_LANGUAGE=python INPUT_WORKING_DIRECTORY=tests/fixtures/python-clean bash gate.sh` | exit 0 |
| dirty fixture でゲートが落ちる（Python） | `INPUT_LANGUAGE=python INPUT_WORKING_DIRECTORY=tests/fixtures/python-dirty bash gate.sh` | exit 非0（1） |

上記4件はローカルで実際に確認済み（clean→0、dirty→1。TypeScript は
`eslint-disable` 1件＋`biome-ignore` 1件、Python は `# noqa` 1件＋
`# pylint: disable` 1件をそれぞれ正しく検出）。CI 側の等価な検証は
`.github/workflows/self-test.yml`（push / PR で自動実行、4通りの
language×clean/dirty マトリクスで clean は素直に、dirty は
`continue-on-error` + outcome チェックで「落ちること」自体をアサートする構成）。
verifier / code-reviewer に渡すルーブリックもこの標準完了条件をデフォルトにする。

### /goal 条件テンプレ

```
/goal
終了状態: <このリポジトリで達成したい具体的な状態>
証明方法:
  - INPUT_LANGUAGE=typescript INPUT_WORKING_DIRECTORY=tests/fixtures/typescript-clean bash gate.sh → exit 0
  - INPUT_LANGUAGE=typescript INPUT_WORKING_DIRECTORY=tests/fixtures/typescript-dirty bash gate.sh → exit 非0
  - INPUT_LANGUAGE=python INPUT_WORKING_DIRECTORY=tests/fixtures/python-clean bash gate.sh → exit 0
  - INPUT_LANGUAGE=python INPUT_WORKING_DIRECTORY=tests/fixtures/python-dirty bash gate.sh → exit 非0
  - (該当すれば) gh pr checks <PR番号> で self-test.yml の clean-passes / dirty-fails が green
ターン上限: 15（超えたら打ち切り）
```

### 注意事項

- **/goal の判定者はコマンドを実行しない**。会話に表出した出力だけで達成判定する
  ため、完了条件のチェックコマンドは毎ターン実行して出力を表示すること。
- ターン上限（暴走時のブレーキ）を条件文に必ず含めること。
- **`v1` タグの付け替え・GitHub Release・Marketplace への公開はループに含めない**
  （ユーザー判断。`v1` は複数バージョンから同一コミットを指し直す移動タグ）。
- **`tests/fixtures/*-dirty` は「わざと汚い」のが仕様**（ゲートが正しく落ちる
  ことを検証するためのデータ）。ループ中にうっかり「修正」しないこと。
  `tests/fixtures/*-clean` も意図的にクリーンな状態を保つための固定データなので
  同様に変更しない。
