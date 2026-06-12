module detector_botao(
    input clk,
    input botao_agora,
    output reg flag_botao
);

    // --- Sincronizador de 2 estágios contra Metastabilidade ---
    reg b_sync0, b_sync1;
    always @(posedge clk) begin
        b_sync0 <= botao_agora; // Se a KEY for active-low, use: <= ~botao_agora;
        b_sync1 <= b_sync0;
    end

    // Debounce simples: O botão precisa ficar estável por ~10ms
    reg [19:0] contador = 20'd0;
    reg estado_estavel = 1'b0;
    reg estado_anterior = 1'b0;

    always @(posedge clk) begin
        // Usamos b_sync1 (sinal filtrado eletricamente) em vez de botao_agora
        if (b_sync1 != estado_estavel) begin
            if (contador < 20'd500_000) begin
                contador <= contador + 1;
            end
                else begin
                estado_estavel <= b_sync1;
                contador <= 0;
            end
        end
        else begin
            contador <= 0;
        end

        // Detector de Borda de Subida no sinal LIMPO e SINCRONIZADO
        estado_anterior <= estado_estavel;

        if (!estado_anterior && estado_estavel)
            flag_botao <= 1; // Pulso de 1 ciclo
        else
            flag_botao <= 0;
    end

endmodule