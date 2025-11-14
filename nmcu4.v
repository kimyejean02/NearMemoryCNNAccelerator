module nmcu4 #(
    parameter A_size = 4,
    parameter kernel_size = 2,
    parameter padding = 0,
    parameter stride = 1,
    parameter output_size = 2,
    parameter width = 8
)(
    input [128-1:0] A,
    input [32-1:0] kernel,
    output [288-1:0] out
);

mac2 mac_0 ({A[15:0], A[47:32]}, kernel, out[31:0]);
mac2 mac_1 ({A[23:8], A[55:40]}, kernel, out[63:32]);
mac2 mac_2 ({A[31:16], A[63:48]}, kernel, out[95:64]);
mac2 mac_3 ({A[47:32], A[79:64]}, kernel, out[127:96]);
mac2 mac_4 ({A[55:40], A[87:72]}, kernel, out[159:128]);
mac2 mac_5 ({A[63:48], A[95:80]}, kernel, out[191:160]);
mac2 mac_6 ({A[79:64], A[111:96]}, kernel, out[223:192]);
mac2 mac_7 ({A[87:72], A[119:104]}, kernel, out[255:224]);
mac2 mac_8 ({A[95:80], A[127:112]}, kernel, out[287:256]);

endmodule