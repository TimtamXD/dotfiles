import { describe, expect, test } from 'claude-code/testing'

import { aStatusFile, HOUR } from './builders'
import { PANE, setUpProgressWorld, STATUS_FOLDER } from './progress-world'

const SURFACES = ['terminal', 'desktop'] as const
const START = { cwd: '/', surface: 'desktop', isInteractive: true } as const

describe('the project progress pane', () => {
  test('shows every thread with what needs Tim at the top, on every surface', async ($, on) => {
    const world = setUpProgressWorld(on)
    world.files.set('working.json', aStatusFile({ threadId: 'w', title: 'Build bank sync' }))
    world.files.set(
      'needs.json',
      aStatusFile({ threadId: 'n', title: 'Push to master', state: 'needs_tim', waitingOn: 'Your OK to push' }),
    )

    await $.session.start(START)

    for (const surface of SURFACES) {
      const ui = await $.ui.mount({ ...PANE, surface })
      const titles = (await ui.findAll({ type: 'Text', text: /· (Push to master|Build bank sync)/ })).map(
        found => found.text,
      )
      expect(titles[0]).toMatch(/Push to master/)
      expect(titles[1]).toMatch(/Build bank sync/)
      expect((await ui.find({ type: 'Text', text: /Waiting on/ }))?.text).toBe(
        'Waiting on you: Your OK to push',
      )
      expect(await ui.find({ type: 'Text', text: /Build bank sync 1 of 4 steps/ })).toBeDefined()
      await ui.unmount()
    }
  })

  test('puts a one-line summary in the status line', async ($, on) => {
    const world = setUpProgressWorld(on)
    world.files.set('needs.json', aStatusFile({ threadId: 'n', state: 'needs_tim' }))
    world.files.set('working.json', aStatusFile({ threadId: 'w' }))

    await $.session.start(START)

    expect(world.statusLines.at(-1)).toBe('Progress: 1 need you · 1 working')
  })

  test('picks up a new status file on the next refresh', async ($, on) => {
    const world = setUpProgressWorld(on)
    await $.session.start(START)

    world.files.set('late.json', aStatusFile({ threadId: 'late', title: 'Late arrival' }))
    await world.clock.advance(30_000)

    const ui = await $.ui.mount({ ...PANE, surface: 'desktop' })
    expect(await ui.find({ type: 'Text', text: /Late arrival/ })).toBeDefined()
    await ui.unmount()
  })

  test('skips a broken status file and still shows the rest', async ($, on) => {
    const world = setUpProgressWorld(on)
    world.files.set('broken.json', '{ half written')
    world.files.set('good.json', aStatusFile({ title: 'Good thread' }))
    world.files.set('notes.txt', 'not a status file')

    await $.session.start(START)

    const ui = await $.ui.mount({ ...PANE, surface: 'desktop' })
    expect(await ui.find({ type: 'Text', text: /Good thread/ })).toBeDefined()
    expect(world.statusLines.at(-1)).toBe('Progress: Nothing needs you · 1 working')
    await ui.unmount()
  })

  test('flags a working thread that has gone quiet for over two hours', async ($, on) => {
    const world = setUpProgressWorld(on)
    world.files.set('quiet.json', aStatusFile({ updatedAt: new Date(Date.parse('2026-11-18T04:00:00Z') - 3 * HOUR).toISOString() }))

    await $.session.start(START)

    const ui = await $.ui.mount({ ...PANE, surface: 'desktop' })
    expect(await ui.find({ type: 'Text', text: /Quiet for 3h/ })).toBeDefined()
    await ui.unmount()
  })

  test('says where it looked when there are no status files yet', async ($, on) => {
    setUpProgressWorld(on)

    await $.session.start(START)

    const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
    expect((await ui.find({ type: 'Text', text: /No status files/ }))?.text).toBe(
      `No status files yet in ${STATUS_FOLDER}`,
    )
    await ui.unmount()
  })

  test('explains calmly when the status folder cannot be read', async ($, on) => {
    const world = setUpProgressWorld(on)
    world.isFolderMissing = true

    await $.session.start(START)

    const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
    expect((await ui.find({ type: 'Text', text: /Can't read/ }))?.text).toBe(
      `Can't read ${STATUS_FOLDER} yet. It appears once a thread writes its first status.`,
    )
    await ui.unmount()
  })

  test('reads from the folder Tim sets in the options', { options: { statusFolder: '/status/elsewhere' } }, async ($, on) => {
    const world = setUpProgressWorld(on)

    await $.session.start(START)

    expect(world.listedFolders).toContain('/status/elsewhere')
  })
})
