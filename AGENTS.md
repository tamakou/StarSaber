# AGENTS.md  
## AI開発ルール（Apple Vision Pro ライトセイバーバトルアプリ）

### 🧠 基本方針
- **英語で思考し、日本語で出力**すること。  
- **最新のApple公式ドキュメント・WWDC情報・VisionOS SDK仕様**を常にリサーチして反映すること。  
- **Swift 6.2 / visionOS 26 / Xcode 16** 環境で動作するコードのみを生成する。  
- **爆速開発を最優先**としつつ、クラッシュ・非推奨APIの使用を避け、VisionOSガイドラインに準拠する。  
- **必ずweb検索も行い最新の情報を常に取得**すること。  
---

### 📁 ファイル運用ルール
- `backup` フォルダの利用および参照は禁止。  
  - 既存コードは**再利用せず、常に新規生成**すること。  
- 既存ファイルを上書き・削除する際は**確認不要**。  
- `AGENTS.md`、`.gitignore`、`.devcontainer` は共通扱いとし、変更・削除禁止。  
- 新規アプリ作成時は、既存ファイルを上書き・削除する前にユーザーにバックアップを促すこと（`backup-プロジェクト名` フォルダ作成）。  

---

### 🧩 VisionOS開発ルール
- プロジェクトテンプレートは **「App」** を基本とし、現実空間との融合（Mixed Reality）を前提に設計。  
- **RealityKit + SwiftUI + Metal** を優先使用。SceneKitやARKitの旧APIは使用しない。  
- **Input System**（手、コントローラ、視線、音声）は最新の `RealityKit.Input` API 仕様を使用。  
- **Spatial Audio**、**光エフェクト**、**物理シミュレーション**を使用する際はパフォーマンス優先で設計。  
- 常に60fps以上を目標にフレームレートを維持する。  

---

### ⚔ 戦闘（ライトセイバー）ロジック実装指針
- 物理演算は `RealityKit.PhysicsBody` を使用。  
- ライトセイバーの衝突は「Trigger-Based」ではなく「Contact-Based」で処理。  
- エフェクトは `MaterialFX` または `ShaderGraph` によるリアルタイム発光処理を行う。  
- キャラクターや敵AIは `EntityComponentSystem (ECS)` 構成で管理する。  
- プレイヤー入力は「手ジェスチャー」と「デバイス回転入力」の両対応とする。  

---

### 🧰 開発プロセスルール
1. **Chatモードで仕様を固めるまでコードを生成しない**。  
2. 機能単位で計画を立て、章立て形式で仕様をFIXする。  
3. コード生成時はファイル単位で出力し、補助ファイル（Assets・Shadersなど）は分離。  
4. ビルド・実行コマンドはユーザーがXcode上で手動実行する。AIは実行しない。  
5. 実装時に使用ライブラリやAPIが非推奨の場合、必ず代替案を提示する。  

---

### 🧾 命名・構成ルール
- モジュール名は PascalCase、変数・関数は camelCase。  
- シーンファイル名は `BattleScene.swift` のように機能が明確に分かる命名に統一。  
- UI構成は `SwiftUI` に統一し、`RealityView` を中心に構築。  
- 物理・レンダリングは `RealityKit` を優先、`SceneKit`・`ARKit` は使用禁止。  

---

### ⚙️ ビルド・実行手順
- プロジェクトを作成後、ターミナルで以下を実行して初期化を確認：  
  ```bash
  xcodebuild -scheme LightsaberBattle -destination 'platform=visionOS'
