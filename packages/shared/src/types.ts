export interface Item {
  id: string;
  name: string;
  purchased: boolean;
  position: number;
  purchased_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface ItemsResponse {
  items: Item[];
}

export interface CreateItemRequest {
  name: string;
}

export interface UpdateItemRequest {
  name?: string;
  purchased?: boolean;
  position?: number;
}

export interface ReorderRequest {
  items: { id: string; position: number }[];
}
