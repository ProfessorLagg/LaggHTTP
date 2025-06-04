const builtin = @import("builtin");
const std = @import("std");

pub const TCPHeader = packed struct {    
    /// Identifies the sending port.
    sourcePort: u16,
    /// Identifies the receiving port.
    destinationPort: u16,
    /// If the SYN flag is set (1), then this is the initial sequence number.
    /// The sequence number of the actual first data byte and the acknowledged number in the corresponding ACK are then this sequence number plus 1.
    /// If the SYN flag is unset (0), then this is the accumulated sequence number of the first data byte of this segment for the current session.
    sequenceNumber: u32,
    /// Has a dual role:
    /// - If the SYN flag is set (1), then this is the initial sequence number. The sequence number of the actual first data byte and the acknowledged number in the corresponding ACK are then this sequence number plus 1.
    /// - If the SYN flag is unset (0), then this is the accumulated sequence number of the first data byte of this segment for the current session.
    acknowledgmentNumber: u32,
    /// Specifies the size of the TCP header in 32-bit words.
    /// The minimum size header is 5 words and the maximum is 15 words thus giving the minimum size of 20 bytes and maximum of 60 bytes, allowing for up to 40 bytes of options in the header.
    /// This field gets its name from the fact that it is also the offset from the start of the TCP segment to the actual data.
    dataOffset: u4,
    /// From 2003 to 2017, the last bit (bit 103 of the header) was defined as the NS (Nonce Sum) flag by the experimental RFC 3540, ECN-nonce. ECN-nonce never gained widespread use and the RFC was moved to Historic status.
    /// For future use and should be set to zero; senders should not set these and receivers should ignore them if set, in the absence of further specification and implementation.
    reserved: u4,

    /// Congestion window reduced (CWR) flag is set by the sending host to indicate that it received a TCP segment with the ECE flag set and had responded in congestion control mechanism.
    flagCWR: u1,
    /// ECN-Echo has a dual role, depending on the value of the SYN flag:
    /// - If the SYN flag is set (1), the TCP peer is ECN capable.
    /// - If the SYN flag is unset (0), a packet with the Congestion Experienced flag set (ECN=11) in its IP header was received during normal transmission. This serves as an indication of network congestion (or impending congestion) to the TCP sender.
    flagECE: u1,
    /// Indicates that the Urgent pointer field is significant.
    flagURG: u1,
    /// Indicates that the Acknowledgment field is significant. All packets after the initial SYN packet sent by the client should have this flag set.
    flagACK: u1,
    /// Push function. Asks to push the buffered data to the receiving application.
    flagPSH: u1,
    /// Reset the connection
    flagRST: u1,
    /// Synchronize sequence numbers. Only the first packet sent from each end should have this flag set. Some other flags and fields change meaning based on this flag, and some are only valid when it is set, and others when it is clear.
    flagSYN: u1,
    /// Last packet from sender
    flagFIN: u1,
    /// The size of the receive window, which specifies the number of window size units that the sender of this segment is currently willing to receive.
    window: u16,
    /// The 16-bit checksum field is used for error-checking of the TCP header, the payload and an IP pseudo-header. The pseudo-header consists of the source IP address, the destination IP address, the protocol number for the TCP protocol (6) and the length of the TCP headers and payload (in bytes).
    checksum: u16,
    /// If the URG flag is set, then this 16-bit field is an offset from the sequence number indicating the last urgent data byte.
    urgentPointer: u16,
};

pub const TCPOptions = packed struct {
    
};
