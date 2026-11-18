import { describe, expect, test } from 'claude-code/testing'

import { countByState, orderForTim } from '../hooks/ordering'
import { aThread, HOUR, NOW } from './builders'

describe('ordering threads for Tim', () => {
  test('threads waiting on Tim come before threads still working', () => {
    const working = aThread({ threadId: 'a', state: 'working' })
    const needsTim = aThread({ threadId: 'b', state: 'needs_tim' })

    const ordered = orderForTim([working, needsTim], NOW)

    expect(ordered.map(thread => thread.threadId)).toEqual(['b', 'a'])
  })

  test('work ready for review comes right after work waiting on Tim', () => {
    const done = aThread({ threadId: 'done', state: 'done' })
    const review = aThread({ threadId: 'review', state: 'review_ready' })
    const working = aThread({ threadId: 'working', state: 'working' })
    const needsTim = aThread({ threadId: 'needs', state: 'needs_tim' })

    const ordered = orderForTim([done, review, working, needsTim], NOW)

    expect(ordered.map(thread => thread.threadId)).toEqual([
      'needs',
      'review',
      'working',
      'done',
    ])
  })

  test('within the same state the most recently updated comes first', () => {
    const older = aThread({ threadId: 'older', updatedAt: NOW - 2 * HOUR })
    const newer = aThread({ threadId: 'newer', updatedAt: NOW - HOUR })

    const ordered = orderForTim([older, newer], NOW)

    expect(ordered.map(thread => thread.threadId)).toEqual(['newer', 'older'])
  })

  test('finished work older than a day drops off the list', () => {
    const oldDone = aThread({ state: 'done', updatedAt: NOW - 25 * HOUR })
    const oldNeedsTim = aThread({
      threadId: 'still',
      state: 'needs_tim',
      updatedAt: NOW - 25 * HOUR,
    })

    const ordered = orderForTim([oldDone, oldNeedsTim], NOW)

    expect(ordered.map(thread => thread.threadId)).toEqual(['still'])
  })

  test('the counts say how many threads are in each state', () => {
    const counts = countByState([
      aThread({ state: 'needs_tim' }),
      aThread({ state: 'needs_tim' }),
      aThread({ state: 'working' }),
    ])

    expect(counts.needs_tim).toBe(2)
    expect(counts.working).toBe(1)
    expect(counts.done).toBe(0)
  })
})
