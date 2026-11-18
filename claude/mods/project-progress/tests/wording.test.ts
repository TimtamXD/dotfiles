import { describe, expect, test } from 'claude-code/testing'

import { describeAge, summarise } from '../hooks/wording'
import { aThread, HOUR, MINUTE, NOW } from './builders'

describe('the words and bars the pane shows', () => {
  test('ages read the way a person says them', () => {
    expect(describeAge(NOW - 20_000, NOW)).toBe('just now')
    expect(describeAge(NOW - 5 * MINUTE, NOW)).toBe('5m ago')
    expect(describeAge(NOW - 3 * HOUR, NOW)).toBe('3h ago')
    expect(describeAge(NOW - 50 * HOUR, NOW)).toBe('2d ago')
  })

  test('the summary leads with what needs Tim and leaves out empty states', () => {
    const summary = summarise([
      aThread({ state: 'needs_tim' }),
      aThread({ state: 'review_ready' }),
      aThread({ state: 'working' }),
      aThread({ state: 'working' }),
    ])

    expect(summary).toBe('2 need you · 2 working')
  })

  test('with nothing waiting the summary says so calmly', () => {
    expect(summarise([aThread({ state: 'done' })])).toBe('Nothing needs you · 1 done')
  })
})
