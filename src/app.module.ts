// app.module.ts
import { Module } from '@nestjs/common';
import { ProductosModule } from './productos/productos.module.js';

@Module({
  imports: [ProductosModule],
  controllers: [],
  providers: [],
})
export class AppModule {}
