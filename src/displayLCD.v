module displayLCD (
    input wire clk,
    input wire rst, // Reset Geral (Vem de ~sistema_ligado)
    input wire btn_send, // Pulso ativo vindo da CPU (enviar instrução)
    input wire [2:0] op_selc,
    input wire [3:0] logger,
    input wire signed [15:0] result,

    output reg [7:0] lcd_data,
    output reg lcd_rs,
    output reg lcd_rw,
    output reg lcd_e
);

    // Registradores Internos
    reg [2:0] reg_op;
    reg [3:0] reg_logger;
    reg signed [15:0] reg_result;
    
    // Flag de controle da tela inicial
    reg is_initial_state;
    reg clear_initial_state;

    // Comandos LCD
    localparam [7:0] CMD_FUNC_SET = 8'h38;
    localparam [7:0] CMD_DISP_ON  = 8'h0C;
    localparam [7:0] CMD_CLEAR    = 8'h01;
    localparam [7:0] CMD_ENTRY    = 8'h06;

    // Timings
    localparam [31:0] D_INIT_WAIT = 32'd2_500_000;
    localparam [31:0] D_CMD_STD   = 32'd2_500;
    localparam [31:0] D_CMD_CLR   = 32'd100_000;
    localparam [31:0] D_PULSE     = 32'd50;

    // --- CONVERSOR BCD ---
    wire [15:0] magnitude;
    assign magnitude = (reg_result < 0) ? -reg_result : reg_result;
    wire [3:0] w_d4, w_d3, w_d2, w_d1, w_d0;

    binario_bcd conversor (
        .binario(magnitude),
        .dezemilhar(w_d4),
        .milhar(w_d3),
        .centena(w_d2),
        .dezena(w_d1),
        .unidade(w_d0)
    );

    // --- DECODIFICADORES COMBINACIONAIS ---
    reg [7:0] current_cmd;
    reg [7:0] current_char;
    reg [31:0] op_string;

    // 1. Multiplexador de Comandos Iniciais
    always @(*) begin
        case (cmd_idx)
            3'd0: current_cmd = CMD_FUNC_SET;
            3'd1: current_cmd = CMD_DISP_ON;
            3'd2: current_cmd = CMD_CLEAR;
            3'd3: current_cmd = CMD_ENTRY;
            default: current_cmd = CMD_FUNC_SET;
        endcase
    end

    // 2. Tradutor de Opcode
    always @(*) begin
        case (reg_op)
            3'b000: op_string = "LOAD";
            3'b001: op_string = "ADD ";
            3'b010: op_string = "ADDI";
            3'b011: op_string = "SUB ";
            3'b100: op_string = "SUBI";
            3'b101: op_string = "MULT";
            3'b110: op_string = "CLR ";
            3'b111: op_string = "DPL ";
            default:op_string = "ERRO";
        endcase
    end

    // 3. Multiplexador de Caracteres do LCD
    always @(*) begin
        current_char = " "; // Valor padrão

        // Se ainda não enviou a 1ª instrução, mostra layout vazio
        if (is_initial_state) begin 
            case (msg_idx)
                // Operação: ---
                6'd0, 6'd1, 6'd2: current_char = "-";
                // Logger: [----]
                6'd10: current_char = "[";
                6'd11, 6'd12, 6'd13, 6'd14: current_char = "-";
                6'd15: current_char = "]";
                // Resultado: +00000
                6'd26: current_char = "+";
                6'd27, 6'd28, 6'd29, 6'd30, 6'd31: current_char = "0";
                default: current_char = " ";
            endcase
        end 
        else begin // Estado normal de processamento
            case (msg_idx)
                6'd0: current_char = op_string[31:24];
                6'd1: current_char = op_string[23:16];
                6'd2: current_char = op_string[15:8];
                6'd3: current_char = op_string[7:0];

                6'd10: current_char = "[";
                6'd11: current_char = reg_logger[3] ? "1" : "0";
                6'd12: current_char = reg_logger[2] ? "1" : "0";
                6'd13: current_char = reg_logger[1] ? "1" : "0";
                6'd14: current_char = reg_logger[0] ? "1" : "0";
                6'd15: current_char = "]";

                6'd26: current_char = (reg_result < 0) ? "-" : "+";
                6'd27: current_char = 8'h30 + w_d4;
                6'd28: current_char = 8'h30 + w_d3;
                6'd29: current_char = 8'h30 + w_d2;
                6'd30: current_char = 8'h30 + w_d1;
                6'd31: current_char = 8'h30 + w_d0;
                default: current_char = " ";
            endcase
        end
    end

    // --- FSM PRINCIPAL ---
    localparam [4:0]
        S_OFF          = 5'd0,
        S_INIT_START   = 5'd1,
        S_INIT_PULSE   = 5'd2,
        S_INIT_WAIT    = 5'd3,
        S_IDLE         = 5'd4,
        S_SYNC_CPU     = 5'd5,
        S_CMD_ADDR     = 5'd6,
        S_CMD_PULSE    = 5'd7,
        S_CMD_WAIT     = 5'd8,
        S_DATA_WRITE   = 5'd9,
        S_DATA_PULSE   = 5'd10,
        S_DATA_WAIT    = 5'd11,
        S_WAIT_RELEASE = 5'd12;

    reg [4:0] state, next_state;
    reg [31:0] cnt, next_cnt;
    reg [2:0] cmd_idx, next_cmd_idx;
    reg [5:0] msg_idx, next_msg_idx;
    reg load_inputs;

    // Memória Sequencial
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            state <= S_OFF;
            cnt <= 0;
            cmd_idx <= 0;
            msg_idx <= 0;
            reg_op <= 0;
            reg_logger <= 0;
            reg_result <= 0;
            is_initial_state <= 1'b1; // Volta para a tela inicial
        end
        else begin
            state <= next_state;
            cnt <= next_cnt;
            cmd_idx <= next_cmd_idx;
            msg_idx <= next_msg_idx;

            if (clear_initial_state) begin
                is_initial_state <= 1'b0; // Apaga a flag quando a 1ª instrução for recebida
            end

            if (load_inputs) begin
                reg_op <= op_selc;
                reg_logger <= logger;
                reg_result <= result;
            end
        end
    end

    // Lógica Combinacional da FSM
    always @(*) begin
        next_state = state;
        next_cnt = cnt;
        next_cmd_idx = cmd_idx;
        next_msg_idx = msg_idx;
        load_inputs = 0;
        clear_initial_state = 0;

        case(state)
            S_OFF: begin
                next_cnt = 0;
                // Só liga a tela quando soltar o botão de Reset/Ligar (rst == 0)
                if (!rst) next_state = S_INIT_START;
            end

            S_INIT_START: begin
                if (cnt < D_INIT_WAIT) next_cnt = cnt + 1;
                else begin next_cnt = 0; next_cmd_idx = 0; next_state = S_INIT_PULSE; end
            end

            S_INIT_PULSE: begin
                if (cnt < D_PULSE) next_cnt = cnt + 1;
                else begin next_cnt = 0; next_state = S_INIT_WAIT; end
            end

            S_INIT_WAIT: begin
                if (cnt < (cmd_idx == 2 ? D_CMD_CLR : D_CMD_STD)) next_cnt = cnt + 1;
                else begin
                    next_cnt = 0;
                    if (cmd_idx < 3) begin next_cmd_idx = cmd_idx + 1; next_state = S_INIT_PULSE; end
                    else begin next_msg_idx = 0; next_state = S_CMD_ADDR; end
                end
            end

            S_IDLE: begin
                if (btn_send) begin 
                    next_cnt = 0; 
                    clear_initial_state = 1; // 1ª instrução recebida, tira a tela de descanso
                    next_state = S_SYNC_CPU; 
                end
            end

            S_SYNC_CPU: begin
                if (cnt < 32'd1000) next_cnt = cnt + 1;
                else begin load_inputs = 1; next_msg_idx = 0; next_cnt = 0; next_state = S_CMD_ADDR; end
            end

            S_CMD_ADDR: begin
                if (msg_idx == 0 || msg_idx == 16) begin next_cnt = 0; next_state = S_CMD_PULSE; end
                else begin next_cnt = 0; next_state = S_DATA_WRITE; end
            end

            S_CMD_PULSE: begin
                if (cnt < D_PULSE) next_cnt = cnt + 1;
                else begin next_cnt = 0; next_state = S_CMD_WAIT; end
            end

            S_CMD_WAIT: begin
                if (cnt < D_CMD_STD) next_cnt = cnt + 1;
                else begin next_cnt = 0; next_state = S_DATA_WRITE; end
            end

            S_DATA_WRITE: begin
                next_cnt = 0; next_state = S_DATA_PULSE;
            end

            S_DATA_PULSE: begin
                if (cnt < D_PULSE) next_cnt = cnt + 1;
                else begin next_cnt = 0; next_state = S_DATA_WAIT; end
            end

            S_DATA_WAIT: begin
                if (cnt < D_CMD_STD) next_cnt = cnt + 1;
                else begin
                    next_cnt = 0;
                    if (msg_idx == 31) next_state = S_WAIT_RELEASE;
                    else begin next_msg_idx = msg_idx + 1; next_state = S_CMD_ADDR; end
                end
            end

            S_WAIT_RELEASE: begin
                if (!btn_send) next_state = S_IDLE;
            end

            default: next_state = S_OFF;
        endcase
    end

    // Saídas
    always @(*) begin
        lcd_e = 0;
        lcd_rs = 0;
        lcd_rw = 0;
        lcd_data = 8'h00;

        case(state)
            S_INIT_PULSE: begin
                lcd_e = 1;
                lcd_data = current_cmd; 
            end

            S_INIT_WAIT: begin
                lcd_data = current_cmd;
            end

            S_CMD_PULSE: begin
                lcd_e = 1;
                lcd_data = (msg_idx == 0) ? 8'h80 : 8'hC0;
            end

            S_CMD_WAIT: begin
                lcd_data = (msg_idx == 0) ? 8'h80 : 8'hC0;
            end

            S_DATA_PULSE: begin
                lcd_e = 1;
                lcd_rs = 1;
                lcd_data = current_char; 
            end

            S_DATA_WAIT: begin
                lcd_rs = 1;
                lcd_data = current_char;
            end
        endcase
    end
endmodule