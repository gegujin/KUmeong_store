import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Observable } from 'rxjs';

@Injectable()
export class RouteContextInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const http = context.switchToHttp();
    const req = http.getRequest() as any;

    const handler = context.getHandler();
    const controller = context.getClass();

    req.__routeContext = {
      controller: controller?.name,
      handler: handler?.name,
      method: req?.method,
      url: req?.originalUrl ?? req?.url,
    };

    return next.handle();
  }
}
