export const DATERANGE_DEP = "app:daterange";

function defaultFrom(): string {
  const d = new Date();
  d.setDate(d.getDate() - 7);
  return d.toISOString().slice(0, 10);
}

function defaultTo(): string {
  return new Date().toISOString().slice(0, 10);
}

export const daterange = $state({
  from: defaultFrom(),
  to:   defaultTo(),
});
