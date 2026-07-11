import axios, { type AxiosInstance } from "axios";
import { tenant } from "@common/stores/tenant.svelte";

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly path: string,
  ) {
    super(`API ${status} — ${path}`);
    this.name = "ApiError";
  }
}

function createInstance(): AxiosInstance {
  if (!tenant.slug) throw new Error("No hay tenant activo — navegá con subdominio: <slug>.localhost");

  const instance = axios.create({
    baseURL: `http://${tenant.slug}.localhost:8000`,
    paramsSerializer: { indexes: null },
  });

  instance.interceptors.response.use(
    res => res,
    err => Promise.reject(
      axios.isAxiosError(err) && err.response
        ? new ApiError(err.response.status, err.config?.url ?? "")
        : err
    ),
  );

  return instance;
}

export const instance = createInstance();
