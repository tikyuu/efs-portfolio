import { useRef, useState } from 'react';

// 画面確認用の架空データ。APIやEFSから取得したファイルではない。
const samples = [
  { name: 'はじめに.txt', type: 'TXT', content: '共有ファイルの画面プレビューです。\nこのファイルはサンプルです。\n' },
  { name: '共有ファイル一覧.csv', type: 'CSV', content: '\uFEFF名前,用途\n設計メモ,学習用サンプル\n' },
  { name: '設計メモ.md', type: 'MD', content: '# 設計メモ\n\n登録・閲覧サービスから共通のEFSを利用する構成案です。\n' },
];

function Icon({ kind, ...props }) {
  const paths = {
    upload: <><path d="M12 16V4m-5 5 5-5 5 5" /><path d="M4 16v4h16v-4" /></>,
    download: <><path d="M12 4v12m-5-5 5 5 5-5" /><path d="M4 17v3h16v-3" /></>,
    refresh: <><path d="M19 8a8 8 0 1 0 1 7" /><path d="M19 3v5h-5" /></>,
    file: <><path d="M6 3h8l4 4v14H6z" /><path d="M14 3v5h4M9 13h6M9 17h4" /></>,
    close: <path d="m7 7 10 10M7 17 17 7" />,
  };
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" {...props}>{paths[kind]}</svg>;
}

function formatSize(size) {
  return size < 1024 ? `${size} B` : `${(size / 1024).toFixed(1)} KB`;
}

function downloadSample(file) {
  const url = URL.createObjectURL(new Blob([file.content], { type: 'text/plain;charset=utf-8' }));
  const link = document.createElement('a');
  link.href = url;
  link.download = file.name;
  link.click();
  window.setTimeout(() => URL.revokeObjectURL(url), 1000);
}

export default function App() {
  const input = useRef(null);
  const uploadInProgress = useRef(false);
  const [selected, setSelected] = useState(null);
  const [uploading, setUploading] = useState(false);
  const [dragging, setDragging] = useState(false);
  const [notice, setNotice] = useState('');

  function choose(files) {
    if (uploadInProgress.current) return;
    if (!files?.length) return;
    if (files.length > 1) {
      setNotice('ファイルは1つずつ選択してください。');
      return;
    }
    setSelected(files[0]);
    setNotice('');
  }

  function clear() {
    if (uploadInProgress.current) return;
    setSelected(null);
    setNotice('');
    if (input.current) input.current.value = '';
  }

  async function upload() {
    if (!selected || uploadInProgress.current) return;
    const file = selected;
    if (file.size > 10 * 1024 * 1024) {
      setNotice('ファイルは10 MiB以内にしてください。');
      return;
    }

    uploadInProgress.current = true;
    setUploading(true);
    setNotice('');
    try {
      const body = new FormData();
      body.append('file', file);
      // 同じサイトのALBを通じて、Pythonの登録APIへ送る。
      const response = await fetch('/upload/', { method: 'POST', body });
      const result = await response.json().catch(() => null);
      if (!response.ok) {
        setNotice(typeof result?.detail === 'string' ? result.detail : '登録できませんでした。');
        return;
      }
      if (typeof result?.filename !== 'string') {
        setNotice('登録結果を確認できませんでした。保存済みの場合があります。');
        return;
      }
      setNotice(`${result.filename} を登録しました。`);
      setSelected(null);
      if (input.current) input.current.value = '';
    } catch {
      setNotice('通信に失敗しました。保存済みの場合もあるため、登録結果を確認してください。');
    } finally {
      uploadInProgress.current = false;
      setUploading(false);
    }
  }

  return (
    <div className="shell">
      <header className="site-header">
        <a className="brand" href="./" aria-label="Shared ホーム">
          <svg className="brand-mark" viewBox="0 0 40 40" aria-hidden="true"><path d="M30 8C19-1 4 9 5 22c1 13 20 18 28 7 4-6 2-15-3-18" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" /></svg>
          <span>shared<span className="brand-period">.</span></span>
        </a>
        <span className="edition">EFS PORTFOLIO <span className="edition-line" /> 01</span>
      </header>

      <main>
        <section className="page-heading" aria-labelledby="page-title">
          <div><p className="eyebrow">YOUR SHARED SPACE</p><h1 id="page-title">共有ファイル</h1></div>
          <span className="preview-badge"><span />プレビュー</span>
        </section>

        <div className="workspace">
          <section className="upload-panel" aria-labelledby="upload-title">
            <div className="section-heading"><span className="section-number">01</span><h2 id="upload-title">登録</h2></div>
            <div className={`drop-area ${dragging ? 'is-dragging' : ''} ${selected ? 'has-file' : ''}`}
              onDragOver={(event) => { event.preventDefault(); setDragging(true); }}
              onDragLeave={(event) => { if (!event.currentTarget.contains(event.relatedTarget)) setDragging(false); }}
              onDrop={(event) => { event.preventDefault(); setDragging(false); choose(event.dataTransfer.files); }}>
              <input ref={input} className="visually-hidden" id="file-input" type="file" disabled={uploading} tabIndex={-1} onChange={(event) => choose(event.target.files)} />
              <div className="upload-symbol"><Icon kind={selected ? 'file' : 'upload'} /></div>
              {selected ? (
                <div className="selected-file" aria-live="polite"><strong>{selected.name}</strong><span>{formatSize(selected.size)}</span><button className="text-button clear-button" disabled={uploading} onClick={clear}><Icon kind="close" />選び直す</button></div>
              ) : (
                <><p className="drop-label">ここにファイルを置く</p><span className="drop-or">または</span><button className="choose-button" onClick={() => input.current?.click()}>ファイルを選択<span aria-hidden="true">↗</span></button></>
              )}
            </div>
            <button className="register-button" disabled={!selected || uploading} onClick={upload} aria-busy={uploading} aria-describedby="upload-note">{uploading ? '登録中…' : '登録する'}<span aria-hidden="true">→</span></button>
            <p id="upload-note" className="subtle-note">1ファイル10 MiBまで。同名ファイルは上書きしません。</p>
            <p className="notice" role="status">{notice}</p>
          </section>

          <section className="library-panel" aria-labelledby="library-title">
            <div className="section-heading library-heading"><span className="section-number">02</span><h2 id="library-title">ファイル</h2><span className="file-count">サンプル {samples.length}件</span><button className="refresh-button" disabled aria-label="一覧を更新（API接続後に利用できます）" title="API接続後に利用できます"><Icon kind="refresh" /></button></div>
            <ul className="file-list">
              {samples.map((file, index) => (
                <li className="file-row" key={file.name}>
                  <span className="file-index">{String(index + 1).padStart(2, '0')}</span>
                  <div className="file-details"><span className="file-name">{file.name}</span><span className="file-meta">{file.type}<span>·</span>{formatSize(new Blob([file.content]).size)}</span></div>
                  <button className="download-button" onClick={() => { downloadSample(file); setNotice(`${file.name} のダウンロードを開始しました。`); }} aria-label={`${file.name} をダウンロード`} title="サンプルをダウンロード"><Icon kind="download" /></button>
                </li>
              ))}
            </ul>
            <div className="library-bottom"><span className="small-ring" /><span>ひとつの場所から、共有する。</span></div>
          </section>
        </div>
      </main>
      <footer><span>SHARED FILE LIBRARY</span><span>一覧はサンプル表示</span></footer>
    </div>
  );
}
