import type { ElementTable } from 'claude-code'

import type { ThreadStatus } from '../types'
import { describeAge, STATE_WORDS } from './wording'

const QUIET_AFTER = 2 * 60 * 60 * 1000

function isQuiet(thread: ThreadStatus, now: number): boolean {
  return thread.state === 'working' && now - thread.updatedAt > QUIET_AFTER
}

function needsTim(thread: ThreadStatus): boolean {
  return thread.state === 'needs_tim' || thread.state === 'review_ready'
}

function stateLabel(thread: ThreadStatus): string {
  return thread.state === 'needs_tim' ? 'NEEDS YOU' : STATE_WORDS[thread.state]
}

function freshness(thread: ThreadStatus, now: number): string {
  const age = describeAge(thread.updatedAt, now)

  return isQuiet(thread, now) ? `Quiet for ${age.replace(' ago', '')}` : `Updated ${age}`
}

export function drawThreadRow(elements: ElementTable, thread: ThreadStatus, now: number) {
  const { Box, Text, Progress } = elements
  const steps = `${thread.stepsDone} of ${thread.stepsTotal} steps`

  return (
    <Box flexDirection="column" marginBottom={1}>
      <Text bold={needsTim(thread)}>
        {stateLabel(thread)} · {thread.title}
      </Text>
      <Progress
        key={`progress-${thread.threadId}`}
        label={thread.title}
        value={thread.stepsDone}
        max={thread.stepsTotal}
        valueText={steps}
      />
      {thread.waitingOn && <Text bold>Waiting on you: {thread.waitingOn}</Text>}
      {thread.currentStep && <Text dimColor>Now: {thread.currentStep}</Text>}
      <Text dimColor>{freshness(thread, now)}</Text>
    </Box>
  )
}
