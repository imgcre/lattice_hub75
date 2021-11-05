module led_top(
	input clk_in, 
	output reg led_out, //正常的时候亮红灯
	input spi_clk,
	output spi_miso,
	input spi_mosi,
	input spi_scsn
);
	localparam MS_ORIGIN = 4'b0000;
	localparam MS_WAIT_SPI_CR2_WRITE = 4'b0001;
	localparam MS_WRITE_SPIIRQEN_REQ = 4'b0010;
	localparam MS_WRITE_SPIIRQEN_DATA = 4'b0011;
	localparam MS_READ_SPI_RXD_REQ = 4'b0100;
	localparam MS_READ_SPI_RXD_DATA = 4'b0101;
	localparam MS_CLEAR_IT_REQ = 4'b0110;
	localparam MS_CLEAR_IT_DATA = 4'b0111;
	localparam MS_IDLE = 4'b1111;

	wire clk_96m;
	reg wb_cyc, wb_stb, wb_we, wb_rst;
	reg [7:0] wb_adr;
	reg [7:0] wb_dat_i;
	wire [7:0] wb_dat_o;
	wire wb_ack_o;
	wire spi_irq;
	
	reg [3:0] main_state;
	wire nrst;
	
	reg [7:0] count;
	reg [7:0] led_light;
	pll pllx4(clk_in, clk_96m, nrst);
	efb spi(clk_96m, wb_rst, wb_cyc, wb_stb, wb_we, wb_adr, wb_dat_i, wb_dat_o, wb_ack_o, spi_clk, spi_miso, spi_mosi, spi_scsn, spi_irq);
	
	always@(posedge clk_96m, negedge nrst) begin
		if(!nrst) begin
			led_out <= 0;
			count <= 0;
		end else begin
			count <= count + 1;
			led_out <= !(count <= led_light);
		end
	end
	
	always@(posedge clk_96m, negedge nrst) begin
		if(!nrst) begin
			main_state <= MS_ORIGIN;
			{wb_cyc, wb_stb, wb_we} <= 3'b000;
			led_light <= 0;
		end else begin
			case(main_state)
				MS_ORIGIN: begin
					main_state <= MS_WAIT_SPI_CR2_WRITE;
					{wb_cyc, wb_stb, wb_we} <= 3'b111;
					wb_adr <= 8'h56;
					wb_dat_i <= 8'h00;
				end
				MS_WAIT_SPI_CR2_WRITE: begin
					if(wb_ack_o) begin
						main_state <= MS_WRITE_SPIIRQEN_REQ;
						{wb_cyc, wb_stb} <= 2'b00;
					end
				end
				MS_WRITE_SPIIRQEN_REQ: begin
					main_state <= MS_WRITE_SPIIRQEN_DATA;
					{wb_cyc, wb_stb, wb_we} <= 3'b111;
					wb_adr <= 8'h5d;
					wb_dat_i <= 8'b00001000;
				end
				MS_WRITE_SPIIRQEN_DATA: begin
					if(wb_ack_o) begin
						main_state <= MS_IDLE;
						{wb_cyc, wb_stb} <= 2'b00;
					end
				end
				MS_READ_SPI_RXD_REQ: begin
					main_state <= MS_READ_SPI_RXD_DATA;
					{wb_cyc, wb_stb, wb_we} <= 3'b110;
					wb_adr <= 8'h5b;
				end
				MS_READ_SPI_RXD_DATA: begin
					if(wb_ack_o) begin
						main_state <= MS_CLEAR_IT_REQ;
						{wb_cyc, wb_stb} <= 2'b00;
						//TODO: 读取spi RXD
						led_light <= wb_dat_o;
					end
				end
				MS_CLEAR_IT_REQ: begin
					main_state <= MS_CLEAR_IT_DATA;
					{wb_cyc, wb_stb, wb_we} <= 3'b111;
					wb_adr <= 8'h5c;
					wb_dat_i <= 8'b00001000;
				end
				MS_CLEAR_IT_DATA: begin
					if(wb_ack_o) begin
						main_state <= MS_IDLE;
						{wb_cyc, wb_stb} <= 2'b00;
					end
				end
				MS_IDLE: begin
					if(spi_irq) begin
						main_state <= MS_READ_SPI_RXD_REQ;
					end
				end
			endcase
		end
	end

endmodule
