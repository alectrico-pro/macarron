hash= { "cargas_count": @cargas.count}
json.merge! hash
json.items do
  json.array! @cargas, partial: 'api/v1/electrico/circuitos/carga', as: :carga
end

