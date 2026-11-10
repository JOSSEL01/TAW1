// productos.service.ts
import { Injectable, Inject, NotFoundException } from '@nestjs/common';
import { CreateProductoDto } from './dto/create-producto.dto.js';
import { UpdateProductoDto } from './dto/update-producto.dto.js';
import type {Pool, RowDataPacket} from 'mysql2/promise';
// RowDataPacket: convierte de objeto a arreglo

@Injectable()
export class ProductosService {

  constructor(@Inject("BASEDEDATOS") private pool: Pool) {}

  async findAll() {
    const [resultado] = await this.pool.query(
      'SELECT * FROM productos');
    return resultado;
  }

  async findOne(id: number) {
    const [resultado] = await this.pool.query<RowDataPacket[]>(
      'SELECT * FROM productos WHERE id = ?',
      [id]);
    if (resultado.length === 0)
      throw new NotFoundException(`Producto ${id} no existe`);
    return resultado[0];
  }

  async create(createProductoDto: CreateProductoDto) {
    const [resultado] = await this.pool.query(
      'INSERT INTO productos (nombre, precio) VALUES (?,?)', 
      [createProductoDto.nombre, createProductoDto.precio ]);
    return resultado;
  }

  update(id: number, updateProductoDto: UpdateProductoDto) {
    return `This action updates a #${id} producto`;
  }

  remove(id: number) {
    return `This action removes a #${id} producto`;
  }
}
