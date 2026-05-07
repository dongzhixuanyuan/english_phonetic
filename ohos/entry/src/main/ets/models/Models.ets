import { util } from '@kit.ArkTS';

export class WordAnnotation {
  id: string;
  word: string;
  phonetic: string;
  normalizedX: number;
  normalizedY: number;
  normalizedWidth: number;
  normalizedHeight: number;

  constructor(word: string = '', phonetic: string = '', normalizedX: number = 0, normalizedY: number = 0,
    normalizedWidth: number = 0.1, normalizedHeight: number = 0.03) {
    this.id = util.generateRandomUUID(true);
    this.word = word;
    this.phonetic = phonetic;
    this.normalizedX = normalizedX;
    this.normalizedY = normalizedY;
    this.normalizedWidth = normalizedWidth;
    this.normalizedHeight = normalizedHeight;
  }

  static fromJSON(json: Record<string, Object>): WordAnnotation {
    const a = new WordAnnotation();
    a.id = json['id'] as string;
    a.word = json['word'] as string;
    a.phonetic = json['phonetic'] as string;
    a.normalizedX = json['normalizedX'] as number;
    a.normalizedY = json['normalizedY'] as number;
    a.normalizedWidth = json['normalizedWidth'] as number;
    a.normalizedHeight = json['normalizedHeight'] as number;
    return a;
  }

  toJSON(): Record<string, Object> {
    return {
      id: this.id,
      word: this.word,
      phonetic: this.phonetic,
      normalizedX: this.normalizedX,
      normalizedY: this.normalizedY,
      normalizedWidth: this.normalizedWidth,
      normalizedHeight: this.normalizedHeight
    };
  }
}

export class TextbookPage {
  id: string;
  name: string;
  imagePath: string;
  order: number;
  annotations: WordAnnotation[];

  constructor(name: string = '', imagePath: string = '', order: number = 0, annotations: WordAnnotation[] = []) {
    this.id = util.generateRandomUUID(true);
    this.name = name;
    this.imagePath = imagePath;
    this.order = order;
    this.annotations = annotations;
  }

  static fromJSON(json: Record<string, Object>): TextbookPage {
    const p = new TextbookPage();
    p.id = json['id'] as string;
    p.name = json['name'] as string;
    p.imagePath = json['imagePath'] as string;
    p.order = json['order'] as number;
    p.annotations = (json['annotations'] as Array<Record<string, Object>>)?.map(a => WordAnnotation.fromJSON(a)) ?? [];
    return p;
  }

  toJSON(): Record<string, Object> {
    return {
      id: this.id,
      name: this.name,
      imagePath: this.imagePath,
      order: this.order,
      annotations: this.annotations.map(a => a.toJSON())
    };
  }
}

export class TextbookUnit {
  id: string;
  name: string;
  order: number;
  pages: TextbookPage[];

  constructor(name: string = '', order: number = 0, pages: TextbookPage[] = []) {
    this.id = util.generateRandomUUID(true);
    this.name = name;
    this.order = order;
    this.pages = pages;
  }

  static fromJSON(json: Record<string, Object>): TextbookUnit {
    const u = new TextbookUnit();
    u.id = json['id'] as string;
    u.name = json['name'] as string;
    u.order = json['order'] as number;
    u.pages = (json['pages'] as Array<Record<string, Object>>)?.map(p => TextbookPage.fromJSON(p)) ?? [];
    return u;
  }

  toJSON(): Record<string, Object> {
    return {
      id: this.id,
      name: this.name,
      order: this.order,
      pages: this.pages.map(p => p.toJSON())
    };
  }
}

export class Textbook {
  id: string;
  name: string;
  coverImagePath: string | null;
  createdAt: number;
  units: TextbookUnit[];

  constructor(name: string = '', coverImagePath: string | null = null, createdAt: number = Date.now(),
    units: TextbookUnit[] = []) {
    this.id = util.generateRandomUUID(true);
    this.name = name;
    this.coverImagePath = coverImagePath;
    this.createdAt = createdAt;
    this.units = units;
  }

  static fromJSON(json: Record<string, Object>): Textbook {
    const t = new Textbook();
    t.id = json['id'] as string;
    t.name = json['name'] as string;
    t.coverImagePath = json['coverImagePath'] as string | null;
    t.createdAt = json['createdAt'] as number;
    t.units = (json['units'] as Array<Record<string, Object>>)?.map(u => TextbookUnit.fromJSON(u)) ?? [];
    return t;
  }

  toJSON(): Record<string, Object> {
    return {
      id: this.id,
      name: this.name,
      coverImagePath: this.coverImagePath,
      createdAt: this.createdAt,
      units: this.units.map(u => u.toJSON())
    };
  }
}
