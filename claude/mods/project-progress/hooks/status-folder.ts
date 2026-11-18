import type { EngineInterface } from 'claude-code'

import type { ProgressSnapshot, ThreadStatus } from '../types'
import { readStatusFile } from './status-file'

async function readOneStatus($: EngineInterface, path: string): Promise<ThreadStatus | undefined> {
  try {
    return readStatusFile(String(await $.fs.read(path)))
  } catch {
    return undefined
  }
}

export async function readStatusFolder($: EngineInterface, folder: string): Promise<ProgressSnapshot> {
  try {
    const entries = await $.fs.list(folder)
    const statusFiles = entries.filter(entry => entry.kind === 'file' && entry.name.endsWith('.json'))
    const statuses = await Promise.all(
      statusFiles.map(entry => readOneStatus($, `${folder}/${entry.name}`)),
    )

    return { threads: statuses.filter(status => status !== undefined), isFolderReadable: true }
  } catch {
    return { threads: [], isFolderReadable: false }
  }
}
