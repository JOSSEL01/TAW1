// productos.module.ts
import { Module } from '@nestjs/common';
import { ProductosService } from './productos.service.js';
import { ProductosController } from './productos.controller.js';
import * as mysql from 'mysql2/promise';

@Module({
  controllers: [ProductosController],
  providers: [ProductosService, {
    provide: "BASEDEDATOS", // token
    useFactory: async () => { // funcion
      return mysql.createPool({
        host: 'localhost',
        database: 'basededatos',
        user: 'root',
        password: ''
      })
    }
  }]
})
export class ProductosModule {}
