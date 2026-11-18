export type ThreadState =
  | 'needs_tim'
  | 'review_ready'
  | 'failed'
  | 'working'
  | 'stopped'
  | 'done'

export type ThreadStatus = {
  threadId: string
  title: string
  state: ThreadState
  waitingOn?: string
  currentStep?: string
  stepsDone: number
  stepsTotal: number
  updatedAt: number
}

export type ThreadCounts = Record<ThreadState, number>

export type ProgressSnapshot = {
  threads: ThreadStatus[]
  isFolderReadable: boolean
}

declare module 'claude-code' {
  interface PluginState {
    'project-progress': { snapshot: Shaped<ProgressSnapshot> }
  }
}
