onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {Clock and Reset}
add wave -noupdate /tbspacewire/Clk
add wave -noupdate /tbspacewire/nReset
add wave -noupdate /tbspacewire/SpwReset
add wave -noupdate -divider {Link State}
add wave -noupdate /tbspacewire/StartedA
add wave -noupdate /tbspacewire/ConnectingA
add wave -noupdate /tbspacewire/RunningA
add wave -noupdate /tbspacewire/StartedB
add wave -noupdate /tbspacewire/ConnectingB
add wave -noupdate /tbspacewire/RunningB
add wave -noupdate -divider {Node A Transmit}
add wave -noupdate /tbspacewire/TxReadyA
add wave -noupdate /tbspacewire/TxWriteA
add wave -noupdate /tbspacewire/TxFlagA
add wave -noupdate -radix hexadecimal /tbspacewire/TxDataA
add wave -noupdate -divider {Node B Receive}
add wave -noupdate /tbspacewire/RxValidB
add wave -noupdate /tbspacewire/RxReadB
add wave -noupdate /tbspacewire/RxFlagB
add wave -noupdate -radix hexadecimal /tbspacewire/RxDataB
add wave -noupdate -divider {Node B Transmit}
add wave -noupdate /tbspacewire/TxReadyB
add wave -noupdate /tbspacewire/TxWriteB
add wave -noupdate /tbspacewire/TxFlagB
add wave -noupdate -radix hexadecimal /tbspacewire/TxDataB
add wave -noupdate -divider {Node A Receive}
add wave -noupdate /tbspacewire/RxValidA
add wave -noupdate /tbspacewire/RxReadA
add wave -noupdate /tbspacewire/RxFlagA
add wave -noupdate -radix hexadecimal /tbspacewire/RxDataA
add wave -noupdate -divider {Data-Strobe Link}
add wave -noupdate /tbspacewire/SpwDataOutA
add wave -noupdate /tbspacewire/SpwStrobeOutA
add wave -noupdate /tbspacewire/SpwDataInB
add wave -noupdate /tbspacewire/SpwStrobeInB
add wave -noupdate /tbspacewire/SpwDataOutB
add wave -noupdate /tbspacewire/SpwStrobeOutB
add wave -noupdate /tbspacewire/SpwDataInA
add wave -noupdate /tbspacewire/SpwStrobeInA
add wave -noupdate -divider Errors
add wave -noupdate /tbspacewire/ErrorDisconnectA
add wave -noupdate /tbspacewire/ErrorParityA
add wave -noupdate /tbspacewire/ErrorEscapeA
add wave -noupdate /tbspacewire/ErrorCreditA
add wave -noupdate /tbspacewire/ErrorDisconnectB
add wave -noupdate /tbspacewire/ErrorParityB
add wave -noupdate /tbspacewire/ErrorEscapeB
add wave -noupdate /tbspacewire/ErrorCreditB
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 0
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {1 us}
