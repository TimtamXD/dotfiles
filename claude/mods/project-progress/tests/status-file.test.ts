import { describe, expect, test } from 'claude-code/testing'

import { readStatusFile } from '../hooks/status-file'
import { aStatusFile, aThread } from './builders'

describe('reading a thread status file', () => {
  test('a complete file becomes a thread status', () => {
    const status = readStatusFile(aStatusFile())

    expect(status).toEqual(aThread())
  })

  test('a file that is not valid JSON is skipped', () => {
    expect(readStatusFile('{ half written')).toBeUndefined()
  })

  test('a file without a title is skipped', () => {
    expect(readStatusFile(aStatusFile({ title: '' }))).toBeUndefined()
  })

  test('a file with a state the pane does not know is skipped', () => {
    expect(readStatusFile(aStatusFile({ state: 'sleeping' }))).toBeUndefined()
  })

  test('a file with an unreadable time is skipped', () => {
    expect(readStatusFile(aStatusFile({ updatedAt: 'soon' }))).toBeUndefined()
  })

  test('steps done never go past the total', () => {
    const status = readStatusFile(aStatusFile({ stepsDone: 9, stepsTotal: 4 }))

    expect(status?.stepsDone).toBe(4)
  })

  test('missing step counts read as no steps yet', () => {
    const status = readStatusFile(
      aStatusFile({ stepsDone: undefined, stepsTotal: undefined }),
    )

    expect(status?.stepsDone).toBe(0)
    expect(status?.stepsTotal).toBe(0)
  })

  test('what the thread is waiting on is kept', () => {
    const status = readStatusFile(
      aStatusFile({ state: 'needs_tim', waitingOn: 'Approve the push' }),
    )

    expect(status?.waitingOn).toBe('Approve the push')
  })
})
