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
        await controller.shortcutDown(at: 10)
        controller.modeDigit(2)
        #expect(controller.mode == modes[1])
        await controller.shortcutUp(at: 11)
        #expect(fake.provider.message(0, "system") == "Mode english.")
        #expect(fake.pasted == ["Testo rifinito. "])
    }

    @Test("0 means no Post-processing, even with a Default Mode")
    func zero() async {
        fake.defaultMode = modes[0]
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        controller.modeDigit(0)
        await controller.shortcutUp(at: 11)
        #expect(fake.provider.requests.isEmpty)
        #expect(fake.pasted == ["Ciao, sto provando Dimmela. "])
    }

    @Test("the last digit wins; a digit with no enabled Mode is ignored")
    func lastWins() async {
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
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
        await controller.shortcutDown(at: 10)
        await controller.shortcutUp(at: 10.1)
        controller.modeDigit(2)
        await controller.shortcutDown(at: 20)
        #expect(fake.provider.message(0, "system") == "Mode english.")
    }

    @Test("digits belong to Dimmela only while recording")
    func capture() async {
        fake.holdsTranscription = true
        let controller = fake.controllerWired()
        #expect(!controller.capturesDigits)
        controller.modeDigit(1)
        #expect(controller.mode == nil)

        await controller.shortcutDown(at: 10)
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
        await controller.shortcutDown(at: 10)
        #expect(controller.modeChoices.count == 9)
        controller.modeDigit(9)
        #expect(controller.mode == fake.enabledModes[8])
    }

    @Test("shift opens and closes the Mode list during a Dictation; a digit chooses and closes it")
    func shiftToggles() async {
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        #expect(!controller.isModeListVisible)

        controller.shiftPressed()
        #expect(controller.isModeListVisible)
        controller.shiftPressed()
        #expect(!controller.isModeListVisible)

        controller.shiftPressed()
        controller.modeDigit(2)
        #expect(!controller.isModeListVisible)
        #expect(controller.mode == modes[1])
    }

    @Test("a digit with the list closed chooses the Mode and leaves the list closed")
    func digitWithListClosed() async {
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        controller.modeDigit(1)
        #expect(controller.mode == modes[0])
        #expect(!controller.isModeListVisible)
    }

    @Test("the arrows move through the list, from Transcript to the last Mode, and Return closes it")
    func arrows() async {
        fake.defaultMode = modes[0]
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        controller.shiftPressed()

        controller.moveModeSelection(by: 1)
        #expect(controller.mode == modes[1])
        controller.moveModeSelection(by: 5)
        #expect(controller.mode == modes[2])
        controller.moveModeSelection(by: -1)
        controller.moveModeSelection(by: -1)
        controller.moveModeSelection(by: -1)
        #expect(controller.mode == nil)
        controller.moveModeSelection(by: -1)
        #expect(controller.mode == nil)
        controller.moveModeSelection(by: 2)

        controller.confirmModeList()
        #expect(!controller.isModeListVisible)
        await controller.shortcutUp(at: 11)
        #expect(fake.provider.message(0, "system") == "Mode english.")
    }

    @Test("the arrows and Return belong to Dimmela only while the list is open")
    func listKeysCapture() async {
        let controller = fake.controllerWired()
        #expect(!controller.capturesModeListKeys)
        await controller.shortcutDown(at: 10)
        #expect(!controller.capturesModeListKeys)
        controller.moveModeSelection(by: 1)
        #expect(controller.mode == nil)

        controller.shiftPressed()
        #expect(controller.capturesModeListKeys)
        controller.confirmModeList()
        #expect(!controller.capturesModeListKeys)
    }

    @Test("the list closes when the Dictation ends, and shift with no Dictation opens nothing")
    func listLifetime() async {
        let controller = fake.controllerWired()
        controller.shiftPressed()
        #expect(!controller.isModeListVisible)

        await controller.shortcutDown(at: 10)
        controller.shiftPressed()
        await controller.shortcutUp(at: 11)
        #expect(!controller.isModeListVisible)
    }

    @Test("with no enabled Modes there is no list to open")
    func noModes() async {
        fake.enabledModes = []
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        controller.shiftPressed()
        #expect(!controller.isModeListVisible)
    }

    @Test("the Mode chosen with a digit stays the Default Mode for the next Dictations")
    func digitSticks() async {
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        controller.modeDigit(3)
        await controller.shortcutUp(at: 11)
        #expect(fake.defaultMode == modes[2])

        await controller.shortcutDown(at: 20)
        #expect(controller.mode == modes[2])
        await controller.shortcutUp(at: 21)
        #expect(fake.provider.message(1, "system") == "Mode x-post.")
    }

    @Test("the Mode chosen with the arrows stays too, and 0 keeps the Transcript alone")
    func arrowsAndZeroStick() async {
        fake.defaultMode = modes[0]
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        controller.shiftPressed()
        controller.moveModeSelection(by: 1)
        #expect(fake.defaultMode == modes[1])

        controller.modeDigit(0)
        #expect(fake.defaultMode == nil)
    }

    @Test("a digit with no Mode leaves the Default Mode alone")
    func unmappedDigitDoesNotStick() async {
        fake.defaultMode = modes[0]
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        controller.modeDigit(8)
        #expect(fake.defaultMode == modes[0])
    }
}
