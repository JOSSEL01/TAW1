// src/productos/dto/create-producto.dto.ts
import { IsString, IsNumber, IsNotEmpty, Length, IsPositive } from "class-validator";
export class CreateProductoDto {
    @IsString({message: 'El nombre debe ser una cadena'})
    @IsNotEmpty({message: 'El nombre no puede ir vacio'})
    @Length(2,100,{message: 'La longitud debe ser de al menos 2 caracteres'})
    nombre: string;
    @IsNumber({maxDecimalPlaces:2},{message: 'Valor no valido'} ) // hasta 2 decimales
    @IsPositive({message: 'Precio no valido'}) // > 0
    precio: number;
}
