module ula(
    input signed [15:0] A, // Corrigido: agora a ULA sabe que A tem sinal
    input signed [15:0] B, // Corrigido: agora a ULA sabe que B tem sinal
    input [2:0] opcode,
    output reg signed [15:0] res_com_sinal
);

    // Opcodes baseados no PDF
    localparam LOAD = 3'b000;
    localparam ADD  = 3'b001;
    localparam ADDI = 3'b010;
    localparam SUB  = 3'b011;
    localparam SUBI = 3'b100;
    localparam MUL  = 3'b101;
    localparam CLR  = 3'b110;
    localparam DISP = 3'b111;

    always@(*) begin
        res_com_sinal = 16'd0; // Garante que não haverá latch
        
        case(opcode)
            // Load: O valor imediato (B) passa direto
            LOAD: res_com_sinal = B;

            // Aritmética Sinalizada Automática
            ADD,
            ADDI: res_com_sinal = A + B;

            SUB,
            SUBI: res_com_sinal = A - B;

            // MUL agora vai funcionar perfeitamente com números negativos!
            MUL:  res_com_sinal = A * B;

            // Clear: Retorna 0
            CLR:  res_com_sinal = 16'd0;

            // Display: Passa o valor do registrador (A)
            DISP: res_com_sinal = A;

            default: res_com_sinal = 16'd0;
        endcase
    end

endmodule