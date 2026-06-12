module binario_bcd (
    input [15:0] binario,
    output reg [3:0] dezemilhar,
    output reg [3:0] milhar,
    output reg [3:0] centena,
    output reg [3:0] dezena,
    output reg [3:0] unidade
);
    // Algoritmo Double Dabble para conversão Binário -> BCD
    integer i;
    reg [19:0] bcd;

    always @(binario) begin
        bcd = 20'd0;
        for (i = 15; i >= 0; i = i - 1) begin
            if (bcd[3:0] >= 5) bcd[3:0] = bcd[3:0] + 3;
            if (bcd[7:4] >= 5) bcd[7:4] = bcd[7:4] + 3;
            if (bcd[11:8] >= 5) bcd[11:8] = bcd[11:8] + 3;
            if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
            if (bcd[19:16] >= 5) bcd[19:16] = bcd[19:16] + 3;

            bcd = bcd << 1;
            bcd[0] = binario[i];
        end

        dezemilhar = bcd[19:16];
        milhar = bcd[15:12];
        centena = bcd[11:8];
        dezena = bcd[7:4];
        unidade = bcd[3:0];
    end

endmodule
