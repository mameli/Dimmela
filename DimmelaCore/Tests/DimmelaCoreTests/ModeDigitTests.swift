import DimmelaCore
import Foundation
import Testing

@MainActor
@Suite("Mode digits")
struct ModeDigitTests {
    let fake = FakeBoundaries()
    let folder = TemporaryFolder()
    let modes: [Mode]

    init() {
        let folder = folder
        let modes = ["clean", "english", "x-post"].map {
            Mode(id: folder.write("\($0).md", "Mode \($0).").path(percentEncoded: false))
        }
        self.modes = modes
        fake.enabledModes = modes
    }

    @Test("a digit while recording applies the enabled Mode at that position")
    func digit() async {
        let controller = fake.controllerWired()
        await controller.shortcutDown(shift: false, at: 10)
        controller.modeDigit(2)
        #expect(controller.mode == modes[1])
        await controller.shortcutUp(at: 11)
        #expect(fake.provider.message(0, "system") == "Mode english.")
        #expect(fake.pasted == ["Testo rifinito. "])
    }

    @Test("0 means no Post-processing, even after shift chose the Default Mode")
    func zero() async {
        fake.defaultMode = modes[0]
        let controller = fake.controllerWired()
        await controller.shortcutDown(shift: true, at: 10)
        controller.modeDigit(0)
        await controller.shortcutUp(at: 11)
        #expect(fake.provider.requests.isEmpty)
        #expect(fake.pasted == ["Ciao, sto provando Dimmela. "])
    }

    @Test("the last digit wins; a digit with no enabled Mode is ignored")
    func lastWins() async {
        let controller = fake.controllerWired()
        await controller.shortcutDown(shift: false, at: 10)
        controller.modeDigit(1)
        controller.modeDigit(3)
        controller.modeDigit(7)
        #expect(controller.mode == modes[2])
        await controller.shortcutUp(at: 11)
        #expect(fake.provider.message(0, "system") == "Mode x-post.")
    }

    @Test("digits work during a Lock")
    func lock() async {
        let controller = fake.controllerWired()
        await controller.shortcutDown(shift: false, at: 10)
        await controller.shortcutUp(at: 10.1)
        controller.modeDigit(2)
        await controller.shortcutDown(shift: false, at: 20)
        #expect(fake.provider.message(0, "system") == "Mode english.")
    }

    @Test("digits belong to Dimmela only while recording")
    func capture() async {
        fake.holdsTranscription = true
        let controller = fake.controllerWired()
        #expect(!controller.capturesDigits)
        controller.modeDigit(1)
        #expect(controller.mode == nil)

        await controller.shortcutDown(shift: false, at: 10)
        #expect(controller.capturesDigits)

        let release = Task { await controller.shortcutUp(at: 11) }
        await fake.untilTranscribing()
        #expect(!controller.capturesDigits)
        controller.modeDigit(1)
        #expect(controller.mode == nil)

        fake.finishTranscription()
        await release.value
    }

    @Test("only the first nine enabled Modes get a digit")
    func nine() async {
        fake.enabledModes = (1...11).map { Mode(id: folder.write("m\($0).md", "M\($0)").path(percentEncoded: false)) }
        let controller = fake.controllerWired()
        await controller.shortcutDown(shift: false, at: 10)
        #expect(controller.modeChoices.count == 9)
        controller.modeDigit(9)
        #expect(controller.mode == fake.enabledModes[8])
    }

    @Test("the Mode list shows while shift is held or after a digit, and hides at the end")
    func listVisibility() async {
        let controller = fake.controllerWired()
        await controller.shortcutDown(shift: false, at: 10)
        #expect(!controller.isModeListVisible)

        controller.shiftChanged(isDown: true)
        #expect(controller.isModeListVisible)
        controller.shiftChanged(isDown: false)
        #expect(!controller.isModeListVisible)

        controller.modeDigit(1)
        #expect(controller.isModeListVisible)
        await controller.shortcutUp(at: 11)
        #expect(!controller.isModeListVisible)
    }

    @Test("starting with shift+fn+space shows the list until shift is released")
    func shiftAtStart() async {
        let controller = fake.controllerWired()
        await controller.shortcutDown(shift: true, at: 10)
        #expect(controller.isModeListVisible)
        controller.shiftChanged(isDown: false)
        #expect(!controller.isModeListVisible)
    }

    @Test("shift with no Dictation shows nothing")
    func shiftWhenIdle() {
        let controller = fake.controllerWired()
        controller.shiftChanged(isDown: true)
        #expect(!controller.isModeListVisible)
    }
}
