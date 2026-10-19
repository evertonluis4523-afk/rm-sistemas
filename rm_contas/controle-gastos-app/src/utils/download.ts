import { saveAs } from 'file-saver';

export function downloadBlob(blob: Blob, filename: string): void {
  saveAs(blob, filename);
}

export async function shareOrDownload(blob: Blob, filename: string, title: string): Promise<void> {
  const file = new File([blob], filename, { type: blob.type });
  const nav = navigator as Navigator & { canShare?: (data: { files?: File[] }) => boolean; share?: (data: ShareData) => Promise<void> };
  if (nav.canShare?.({ files: [file] }) && nav.share) {
    try {
      await nav.share({ files: [file], title });
      return;
    } catch {
      // usuário cancelou o compartilhamento — cai para download
    }
  }
  downloadBlob(blob, filename);
}
